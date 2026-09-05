add_executable(pelliper)

ecm_add_qml_module(pelliper
    URI
    org.kde.pelliper
)

target_sources(pelliper
    PRIVATE
    main.cpp
)

ecm_target_qml_sources(pelliper
    SOURCES
    qml/main.qml
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
    KF6::I18n
    KF6::I18nQml
    KF6::CoreAddons
    KF6::IconThemes
)

add_dependencies(pelliper pelliper_daemon)

install(TARGETS pelliper ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
