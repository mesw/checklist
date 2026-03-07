cmake_minimum_required(VERSION 3.25)
project(checklist VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt6 — set CMAKE_PREFIX_PATH if not using system Qt
# e.g.: cmake -B build -DCMAKE_PREFIX_PATH=~/Qt/6.8.3/gcc_64
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Quick Qml Network)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(checklist
    main.cpp
    checklistmanager.cpp
    checklistmanager.h
)

qt_add_qml_module(checklist
    URI ChecklistApp
    VERSION 1.0
    QML_FILES
        Main.qml
        LoadingScreen.qml
        ChecklistScreen.qml
        CelebrationOverlay.qml
)

target_link_libraries(checklist PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Network
)

# ── WebAssembly ───────────────────────────────────────────────────────────────
if(EMSCRIPTEN)
    target_compile_definitions(checklist PRIVATE CHECKLIST_WASM)

    # Fetch checklists/index.json and CSV files from the server at runtime.
    # Qt WASM translates QNetworkAccessManager to the browser fetch API.
    target_link_options(checklist PRIVATE
        "SHELL:-s ALLOW_MEMORY_GROWTH=1"
        "SHELL:-s EXPORTED_RUNTIME_METHODS=[getValue]"
    )

    # Embed Qt's QML engine + fonts; no app-specific data files needed.
    set_target_properties(checklist PROPERTIES
        QT_WASM_INITIAL_MEMORY "64MB"
    )
endif()

install(TARGETS checklist RUNTIME DESTINATION bin)
