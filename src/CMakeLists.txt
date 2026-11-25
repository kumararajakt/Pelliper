add_executable(pelliper)

ecm_add_qml_module(pelliper
    URI "com.pelliper.app"
    GENERATE_PLUGIN_SOURCE
)

target_sources(pelliper PRIVATE
    main.cpp
    app/AppSettings.h
    app/AppSettings.cpp
    app/AccountController.h
    app/AccountController.cpp
    app/MessageController.h
    app/MessageController.cpp
    app/NotificationService.h
    app/NotificationService.cpp
    ipc/DaemonClient.h
    ipc/DaemonClient.cpp
    models/FolderModel.h
    models/FolderModel.cpp
    models/ThreadListModel.h
    models/ThreadListModel.cpp
)

ecm_target_qml_sources(pelliper
    SOURCES
        qml/Main.qml
        qml/components/FolderSidebar.qml
        qml/components/MessageListPane.qml
        qml/components/MessageViewPane.qml
        qml/dialogs/AccountSetupDialog.qml
        qml/dialogs/ComposerDialog.qml
        qml/dialogs/SettingsDialog.qml
)

target_link_libraries(pelliper PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    KF6::Kirigami
    KF6::I18n
    KF6::I18nQml
    KF6::CoreAddons
    KF6::IconThemes
    KF6::Notifications
)

if(Qt6WebEngineQuick_FOUND)
    target_sources(pelliper PRIVATE
        web/CidSchemeHandler.h
        web/CidSchemeHandler.cpp
    )
    target_link_libraries(pelliper PRIVATE Qt6::WebEngineQuick)
    target_compile_definitions(pelliper PRIVATE HAVE_WEBENGINE=1)
endif()

install(TARGETS pelliper ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
