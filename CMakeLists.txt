cmake_minimum_required(VERSION 3.20)
project(pelliper)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)
include(ECMQmlModule)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    Gui
    QuickControls2
    Widgets
    DBus
)

find_package(KF6 REQUIRED COMPONENTS
    Kirigami
    I18n
    CoreAddons
    QQC2DesktopStyle
    IconThemes
)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)

# Rust daemon build
add_custom_target(pelliper_daemon
    ALL
    COMMAND cargo build --release --target-dir ${CMAKE_CURRENT_BINARY_DIR}/daemon/target
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/daemon
    COMMENT "Building Rust daemon"
)

install(
    PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/daemon/target/release/pelliper-daemon
    DESTINATION ${KDE_INSTALL_BINDIR}
)

add_subdirectory(src)

install(PROGRAMS pelliper.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES pelliper.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
