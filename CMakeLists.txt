cmake_minimum_required(VERSION 3.21)
project(pelliper VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Qml
    Quick
    QuickControls2
    Network
)

find_package(Qt6 COMPONENTS WebEngineQuick QUIET)
find_package(KF6Kirigami REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6I18n REQUIRED)
find_package(KF6IconThemes REQUIRED)
find_package(KF6QQC2DesktopStyle REQUIRED)

qt_add_executable(pelliper
    src/main.cpp
    src/ipc/DaemonClient.h
    src/ipc/DaemonClient.cpp
)

qt_add_qml_module(pelliper
    URI com.pelliper.app
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
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
    KF6::CoreAddons
    KF6::I18n
    KF6::IconThemes
)

if(Qt6WebEngineQuick_FOUND)
    target_link_libraries(pelliper PRIVATE Qt6::WebEngineQuick)
    target_compile_definitions(pelliper PRIVATE HAVE_WEBENGINE=1)
endif()

# Optional convenience target to build the Rust daemon submodule
find_program(CARGO_EXECUTABLE cargo)
if(CARGO_EXECUTABLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/daemon/Cargo.toml")
    add_custom_target(pelliper-daemon
        COMMAND ${CARGO_EXECUTABLE} build
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/daemon"
        COMMENT "Building pelliper-daemon (Rust)"
    )
endif()

install(TARGETS pelliper DESTINATION bin)
install(FILES packaging/com.pelliper.Pelliper.desktop DESTINATION share/applications)
install(FILES packaging/com.pelliper.Pelliper.metainfo.xml DESTINATION share/metainfo)
