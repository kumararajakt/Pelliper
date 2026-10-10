# AGENTS.md

Kirigami-based email client (built for the KDE ecosystem but **not** a KDE
project). **Two processes, no push IPC**:

- `src/` — C++ / Qt6 / Kirigami UI (`pelliper`), QML module `app.pelliper`
- `daemon/` — Rust daemon (`pelliper-daemon`), tokio + zbus; owns IMAP/SMTP/keyring

The daemon **never sends events back to the UI**. The UI opens the SQLite cache
(`~/.local/share/pelliper/cache.db`, WAL) **read-only**
(`QSQLITE_OPEN_READONLY`) and every `*Model` singleton watches `cache.db`,
`-wal` and `-shm` with `QFileSystemWatcher`, debouncing with a refresh timer
before re-querying. Design implication: a new feature writes results to the
cache from the daemon and exposes them through a `*Model` — don't add
daemon→UI signals. `docs/SYNC_ARCHITECTURE.md` describes this in detail.

IPC is D-Bus `app.pelliper.Daemon` (session bus). C++ side:
`src/daemonclient.cpp` (singleton used from QML). Rust side layout:

- `daemon/src/main.rs` — thin bootstrap (`Daemon` struct, worker spawn, `main()`)
- `daemon/src/dbus.rs` — the zbus `#[interface]` impl with all D-Bus methods
- `daemon/src/outbox.rs` — `outbox_flusher` + `send_with_auth` SMTP helper
- `daemon/src/cache.rs` — all SQLite access + FTS5 index
- `daemon/src/imap.rs` — `ImapSession`, connection tests, header/body parsing
- `daemon/src/{smtp,oauth,secrets}.rs` — `secrets.rs` is the keyring wrapper
  (service name `"pelliper"`)
- `daemon/src/types.rs` — shared data types (`Account`, `Folder`, `Message`,
  `AttachmentRecord`, `OutboxItem`, `FolderKind`/`ImapFolder`/
  `ImapMessageSummary`, `EmailAttachment`)
- `daemon/src/worker.rs` + `src/worker/{handlers,prefetch,backfill,idle}.rs` —
  the per-account worker: one task per account with a priority-ordered loop
  (user requests → body prefetch → attachment prefetch → backfill → IDLE).
  Cross-module entry points are `pub(super)` (e.g. `handle_request` in
  `handlers.rs`), so keep submodule method visibility in mind when adding
  worker logic.

The `app.pelliper` namespace covers three identifiers that must stay in sync:
the QML module URI, the D-Bus bus name/interface (`app.pelliper.Daemon`), and
the D-Bus object path (`/app/pelliper/Daemon`). This project is **not** a
KDE project (it only uses Kirigami) — do not reintroduce `org.kde.*`.

## Build

The two halves are built **separately** — the CMake daemon integration is
currently commented out (`pelliper_daemon` custom target and
`add_dependencies(pelliper pelliper_daemon)` in `CMakeLists.txt` /
`src/CMakeLists.txt`), so `cmake --build build` builds the UI **only**.

```
cmake --build build            # or: ninja -C build   → build/bin/pelliper
cd daemon && cargo build --release   # → daemon/target/release/pelliper-daemon
```

- Rust artifacts therefore land in `daemon/target/release/`, **not**
  `build/daemon/target/` (a leftover from when CMake drove cargo). The daemon
  is a release build even though the CMake build is Debug.
- Existing `build/` is configured with Ninja, Debug, install prefix `/usr`,
  `KDE_INSTALL_USE_QT_SYS_PATHS=ON` (system Qt6/KF6 from `/usr`). Fresh
  configure: `cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr`.
- `.clangd` expects the compile DB in `build/`.
- The QML module is staged at `build/bin/app/pelliper/`, so the UI runs from the
  build tree without installing. That directory can hold stale QML from deleted
  sources (e.g. `AppWindow.qml`) — trust `src/qml/`, not the staging dir.
- QML entry: `engine.loadFromModule("app.pelliper", "Main")` in
  `src/main.cpp`; `src/qml/Main.qml` is the root `Kirigami.ApplicationWindow`
  and `MainWindow.qml` is a page pushed onto its `pageStack`.
- `PelliperMenuBar` and the `Shortcut`s in `Main.qml` reach into
  `root.pageStack.currentItem` by **duck typing** (`setFolderMode`,
  `refreshMessages`, `openCompose`) — a new page needs those functions for the
  menu/shortcuts to work.
- New QML files must be listed in `ecm_target_qml_sources` in
  `src/CMakeLists.txt`. New C++ classes need `QML_ELEMENT` (`QML_SINGLETON`
  for the app singletons: `DaemonClient`, `Oauth`, `Autodiscover`,
  `TrayNotifier`, and the `*Model`s) in their **header**, plus a `.cpp` entry
  in `target_sources` — headers are not listed (AUTOMOC picks them up) and
  there is no manual `qmlRegister*` anywhere.

## Verification

There is no CI. The daemon has a small unit-test suite (pure functions, no
network/D-Bus) — run it with `cargo test` in `daemon/`. There are no UI tests
and `qmllint` is not installed, so a clean build plus a live run is the
verification step.

The UI does **not** start the daemon. To exercise end-to-end, run both (they
need a session D-Bus; use `dbus-run-session` headless). OAuth needs
`PELLIPER_*_CLIENT_ID/_CLIENT_SECRET` in `~/.local/share/pelliper/.env`:

```
dbus-run-session -- bash -c \
  './build/bin/pelliper & ./daemon/target/release/pelliper-daemon & sleep 20'
```

Closing the window does **not** quit: `Main.qml`'s `onClosing` sets
`close.accepted = false` and hides to the tray. Only `Ctrl+Q` or the tray
"Quit" action exits — kill the process when running headless.

Drive the daemon with busctl and inspect what the UI renders (the cache):

```
busctl --user introspect app.pelliper.Daemon /app/pelliper/Daemon   # method signatures
busctl --user call app.pelliper.Daemon /app/pelliper/Daemon app.pelliper.Daemon SyncAll
busctl --user call app.pelliper.Daemon /app/pelliper/Daemon app.pelliper.Daemon SetIdleFolder xs 1 INBOX
sqlite3 ~/.local/share/pelliper/cache.db "SELECT path, kind FROM folders;"
sqlite3 ~/.local/share/pelliper/cache.db "SELECT folder_path, COUNT(*) FROM messages GROUP BY folder_path;"
```

The worker connects lazily: it bootstraps (lists folders, syncs first pages)
at startup **only** when the account has no cached messages **or** its
`folders` rows are missing (a broken state that would render an empty sidebar);
otherwise the first connect is driven by a request (`SyncAll`,
`SetIdleFolder`, `LoadBody`, …). A healthy daemon that looks "idle" and a
silently dead one are indistinguishable from the logs alone — check the cache.

## The daemon is a nested git repo

`daemon/` is registered as a submodule with a local relative URL (`./daemon`)
that cannot be fetched. Treat it as its own git repo: commit Rust changes
inside `daemon/` first, then commit the updated gitlink in the parent repo.
Don't rely on `git submodule update`. `daemon/target` is gitignored there;
format with `cargo fmt`.

## Cache schema gotchas

- `daemon/src/cache.rs` has **no migration framework**: `PRAGMA user_version=1`
  is set unconditionally and the schema is a block of
  `CREATE TABLE IF NOT EXISTS`. Adding a *column* therefore does nothing to an
  existing `cache.db` — bump the pragma and add real migration SQL, or delete
  `~/.local/share/pelliper/cache.db` while developing. Deleting it also drops
  the `accounts` rows (the OAuth refresh token itself lives in the keyring), so
  the account has to be re-added before it will sync again.
- `ALTER TABLE ... DROP COLUMN` is **refused while any trigger references the
  column** (verified on SQLite 3.53.4), so dropping a column means: drop the
  triggers, drop the column, then recreate them against whatever now owns the
  data.
- **`messages` holds per-message *state* only** — `account_id`, `folder_path`,
  `uid`, `has_attachments`, `is_read`, `is_starred`, `preview`. Every header
  lives in `message_headers` (`subject`, `from_addr`, `sender_addr`,
  `reply_to_addr`, `to_addr`, `cc_addr`, `bcc_addr`, `date`, `date_ts`,
  `in_reply_to`, `references_`, `message_id`). Both tables share the
  composite key, and `message_headers` is FK'd to `messages` with
  `ON DELETE CASCADE`, so:
  - **write order is load-bearing** — `upsert_message` must precede
    `save_message_headers` or the insert fails the foreign key. That ordering is
    also why the FTS triggers fire from `message_headers`, not `messages`.
  - `move_message` must copy all three tables (`messages`, `message_headers`,
    `bodies`) before deleting the source row.
- **The six `*_addr` columns are a cross-language contract**, like `folders.kind`.
  Each holds a JSON array of `{name, email}` objects —
  `[{"name":"Alice","email":"alice@example.com"}]` — written by
  `envelope_addresses` (FETCH path) and `address_list_from_raw` (body-fetch
  path), which must agree because either can write the same row. An absent
  header is the two-character string `[]`, never NULL and never `""`.
  - Structured rather than a flat `"Alice <alice@example.com>"` so recipients
    stay addressable: RFC3501 group syntax gives a name with a NIL host, which a
    display string would turn into a bogus address.
  - The UI renders one back to text on read via `addressDisplayString()` in
    `src/addressfield.h` — there is deliberately no display column. The output
    keeps the `Name <addr-spec>` shape because `extractEmail()` in
    `MessageListView.qml` regexes `/<([^>]+)>/` out of it for the avatar and
    the reply address.
  - Sorting on `h.from_addr` is sorting on the JSON. That is correct and needs
    no second expression: `serde` always emits `name` first, so every value
    shares the same `{"name":"` prefix and the comparison lands on the name,
    then the address.
  - FTS indexes `from_addr` as its `sender` column. FTS5 tokenizes the JSON
    punctuation away, so both the display name and the address stay searchable.
- **`SUMMARY_FETCH_QUERY` fetches `HEADER.FIELDS (REFERENCES IN-REPLY-TO)`,
  not the whole header block.** `ENVELOPE` has exactly ten fields and **no
  `references`**, and `src/threadmodel.cpp` builds its union-find from
  `references_` alone — with it empty every message is its own thread root.
  The full `BODY.PEEK[HEADER]` cost ~5.6 KB/message (6.0 MB over 1067 messages)
  of almost entirely `Return-Path`, `DKIM-Signature`, `ARC-Seal` and `Received`
  that nothing read; the two-field list is ~100 bytes. `raw_header` is gone, so
  `Message-Headers` fields come from `ENVELOPE` and there is no raw-header
  fallback for a server that omits it.
- **Order by `message_headers.date_ts`, never `date`.** `date` is the raw
  `Date:` header, so `ORDER BY date` sorts lexically on the weekday name —
  verified: "Wed, 8 Jul" sorts *after* "Wed, 9 Sep". `date_ts` is the parsed
  unix timestamp. The UI list models LEFT JOIN the header table and sort on
  `h.date_ts`; a message with no header row gives NULL, which sorts last.
- `messages_fts` is maintained by SQL triggers, so FTS content follows writes
  automatically — don't reindex from the daemon by hand. Two constraints, both
  learned the hard way:
  - Every trigger **rebuilds the whole FTS row** (DELETE, then INSERT…SELECT
    over `messages` ⋈ `message_headers` ⋈ `bodies`). FTS5 rejects a *partial*
    INSERT against an existing rowid with `constraint failed`, and that error
    rolls back the **enclosing** statement. The old `bodies_fts_ai` did
    `INSERT INTO messages_fts(body, rowid) VALUES(...)`, so every `save_body`
    failed and rolled back — bodies were never stored or indexed, hidden by
    `let _ = cache.save_body(...)` at every call site. Don't reintroduce
    partial inserts, and don't swallow write errors.
  - There is deliberately **no trigger on `messages` UPDATE**. Flag changes fire
    it constantly and reindexing on every read toggle is pure waste. A naive
    one would DELETE the whole FTS row and reinsert only the (always-empty)
    `preview`, destroying the subject/sender index.
- `folders.kind` is a cross-language contract: the daemon persists its
  attribute-derived classification (`FolderKind::as_str()` in
  `daemon/src/types.rs`) and the UI resolves it via
  `FolderModel::roleFromKind()` in `src/foldermodel.cpp`. Keep the two string
  sets in sync when adding a folder role; `"custom"`/empty means "no SPECIAL-USE
  attribute seen", in which case the UI falls back to name heuristics.

## OAuth / env files

- `.env` at repo root and in `daemon/` is gitignored; keys are documented in
  `daemon/.env.example`: `PELLIPER_{GOOGLE,MICROSOFT}_CLIENT_ID/_CLIENT_SECRET`.
- Both processes load env from `~/.local/share/pelliper/.env` first, falling
  back to `./.env` (UI: hand-rolled loader in `src/main.cpp`; daemon:
  `dotenvy` in `daemon/src/main.rs`). OAuth account setup fails at runtime
  unless these are set.

## Daemon behavior to know

- `AddAccount` saves the account even when the IMAP connection test fails
  (logs a warning and continues), then spawns the worker.
- Failed `SendEmail` calls are queued to the `outbox` table; the outbox
  flusher retries every 30s and drops a message after 10 attempts
  (`OUTBOX_FLUSH_INTERVAL_SECS` / `MAX_OUTBOX_ATTEMPTS` in `daemon/src/outbox.rs`).
- Runtime data lives in `~/.local/share/pelliper/`: `cache.db` (schema +
  FTS5 search index), `attachments/`, `.env`. There is **no daemon log
  file** — `tracing_subscriber::fmt` writes to stdout only, so capture the
  daemon's output (e.g. via `dbus-run-session`) when debugging.

## Docs

`docs/*.md` is gitignored but valuable (`App_design.md`,
`SYNC_ARCHITECTURE.md`, `todo.md`, `bugs.md`). It drifts: the D-Bus method
names (`AddAccount`, `SetMessageRead`, `MoveMessage`, `DeleteMessage`,
`SearchAddresses`, `BlockSender`, …) and cache schema (`folder_path`,
`references_`, `in_reply_to`) in the code differ from what the docs list.
`docs/todo.md` also predates the `ui/` → `src/` rename. Trust the code.
