cmake_minimum_required(VERSION 3.25)
project(checklist VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Quick Qml Network LinguistTools)

qt_standard_project_setup(REQUIRES 6.8)

file(GLOB CHECKLIST_MD_FILES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/checklists/*.md"
)

qt_add_executable(checklist
    main.cpp
    checklistmanager.cpp
    checklistmanager.h
    languagemanager.cpp
    languagemanager.h
    ${CHECKLIST_MD_FILES}
    "${CMAKE_SOURCE_DIR}/checklists/index.json"
)

source_group("Checklists" FILES
    ${CHECKLIST_MD_FILES}
    "${CMAKE_SOURCE_DIR}/checklists/index.json"
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
set(EMOJI_FONT "${CMAKE_SOURCE_DIR}/third_party/noto-emoji/fonts/NotoColorEmoji.ttf")

if(EXISTS "${EMOJI_FONT}")
    # Qt resource system requires relative paths — set an alias so the
    # absolute submodule path is exposed as "NotoColorEmoji.ttf" inside
    # the resource prefix /fonts/
    set_source_files_properties("${EMOJI_FONT}"
        PROPERTIES QT_RESOURCE_ALIAS "NotoColorEmoji.ttf"
    )
    qt_add_resources(checklist "appfonts"
        PREFIX "/fonts"
        FILES "${EMOJI_FONT}"
        BIG_RESOURCES
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

# ── Checklists ────────────────────────────────────────────────────────────────

# cmake script that regenerates index.json from the .md files in checklists/
file(WRITE "${CMAKE_BINARY_DIR}/gen_checklist_index.cmake" [=[
    file(GLOB md_files LIST_DIRECTORIES false "${CHECKLISTS_DIR}/*.md")
    list(SORT md_files)
    set(entries)
    foreach(f ${md_files})
        get_filename_component(name "${f}" NAME_WE)

        # Extract title from the first "# " heading in the file
        set(title "${name}")
        file(STRINGS "${f}" file_lines REGEX "^# " LIMIT_COUNT 5 ENCODING UTF-8)
        if(file_lines)
            list(GET file_lines 0 title_line)
            string(SUBSTRING "${title_line}" 2 -1 title)
            string(STRIP "${title}" title)
            string(REPLACE "**" "" title "${title}")
        endif()

        # Escape backslash and double-quote for JSON safety
        string(REPLACE "\\" "\\\\" title "${title}")
        string(REPLACE "\"" "\\\"" title "${title}")

        list(APPEND entries "  {\"name\": \"${name}\", \"title\": \"${title}\"}")
    endforeach()
    list(JOIN entries ",\n" body)
    file(WRITE "${OUTPUT_FILE}" "[\n${body}\n]\n")
]=])

# Regenerate index.json whenever any .md file changes
add_custom_target(checklist_index ALL
    COMMAND ${CMAKE_COMMAND}
        -DCHECKLISTS_DIR=${CMAKE_SOURCE_DIR}/checklists
        -DOUTPUT_FILE=${CMAKE_SOURCE_DIR}/checklists/index.json
        -P ${CMAKE_BINARY_DIR}/gen_checklist_index.cmake
    DEPENDS ${CHECKLIST_MD_FILES}
    COMMENT "Generating checklists/index.json"
    VERBATIM
)

# Copy checklists/ next to the output after each build (desktop and WASM)
add_custom_command(TARGET checklist POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/checklists"
        "$<TARGET_FILE_DIR:checklist>/checklists"
    COMMENT "Copying checklists to output directory"
    VERBATIM
)

install(TARGETS checklist RUNTIME DESTINATION bin)

# ── Translations ──────────────────────────────────────────────────────────────
qt_add_translations(checklist
    TS_FILES translations/checklist_de.ts
    RESOURCE_PREFIX /translations
)
