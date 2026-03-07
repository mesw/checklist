cmake_minimum_required(VERSION 3.25)
project(checklist VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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

# ── Emoji font ────────────────────────────────────────────────────────────────
# Source: git submodule at third_party/noto-emoji
#   git submodule add https://github.com/googlefonts/noto-emoji.git third_party/noto-emoji
#
# License: SIL Open Font License 1.1 — free to embed in any application.
#   https://github.com/googlefonts/noto-emoji/blob/main/fonts/LICENSE
#
# We use the monochrome TTF (not the color WOFF2) because Qt's text engine
# handles outline fonts reliably on all platforms including WASM.
set(EMOJI_FONT "${CMAKE_SOURCE_DIR}/third_party/noto-emoji/fonts/NotoEmoji-Regular.ttf")

if(EXISTS "${EMOJI_FONT}")
    qt_add_resources(checklist "appfonts"
        PREFIX "/fonts"
        FILES "${EMOJI_FONT}"
    )
    target_compile_definitions(checklist PRIVATE HAS_EMOJI_FONT)
    message(STATUS "Emoji font found: ${EMOJI_FONT}")
else()
    message(WARNING
        "Emoji font not found at ${EMOJI_FONT}\n"
        "Run: git submodule update --init --recursive")
endif()

target_link_libraries(checklist PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Network
)

# ── WebAssembly ───────────────────────────────────────────────────────────────
if(EMSCRIPTEN)
    target_compile_definitions(checklist PRIVATE CHECKLIST_WASM)

    target_link_options(checklist PRIVATE
        "SHELL:-s ALLOW_MEMORY_GROWTH=1"
        "SHELL:-s EXPORTED_RUNTIME_METHODS=[getValue]"
    )

    set_target_properties(checklist PROPERTIES
        QT_WASM_INITIAL_MEMORY "64MB"
    )
endif()

install(TARGETS checklist RUNTIME DESTINATION bin)
