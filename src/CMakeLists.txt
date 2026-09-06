add_executable(pelliper)

set_target_properties(pelliper PROPERTIES AUTOMOC ON)

ecm_add_qml_module(pelliper
    URI
    org.kde.pelliper
)

target_sources(pelliper
    PRIVATE
    main.cpp
    autodiscover.cpp
    autodiscover.h
    oauth.cpp
    oauth.h
)

ecm_target_qml_sources(pelliper
    SOURCES
    qml/Main.qml
    qml/ThreePaneView.qml
    qml/AddAccountPage.qml
    qml/ComposePage.qml
)

target_link_libraries(pelliper
    PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::DBus
    Qt6::Network
    KF6::I18n
    KF6::I18nQml
    KF6::CoreAddons
    KF6::IconThemes
)

add_dependencies(pelliper pelliper_daemon)

install(TARGETS pelliper ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
