cmake_minimum_required(VERSION 3.20)
project(pelliper VERSION 0.1.0 LANGUAGES CXX)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)
include(ECMQmlModule)
include(FeatureSummary)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Qml
    Quick
    QuickControls2
    Network
)

find_package(Qt6 COMPONENTS WebEngineQuick QUIET)

find_package(KF6 REQUIRED COMPONENTS
    Kirigami
    I18n
    CoreAddons
    IconThemes
    QQC2DesktopStyle
)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)

add_subdirectory(src)

# Optional convenience target to build the Rust daemon submodule
find_program(CARGO_EXECUTABLE cargo)
if(CARGO_EXECUTABLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/daemon/Cargo.toml")
    add_custom_target(pelliper-daemon
        COMMAND ${CARGO_EXECUTABLE} build
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/daemon"
        COMMENT "Building pelliper-daemon (Rust)"
    )
endif()

install(PROGRAMS packaging/com.pelliper.Pelliper.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES packaging/com.pelliper.Pelliper.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
