# find wasm cmd
include(FindPackageHandleStandardArgs)

if ("${WASM_ROOT}" STREQUAL "")
    if (APPLE)
        set(WASM_ROOT "/usr/local/wasm")
    elseif (UNIX AND NOT APPLE)
        set(WASM_ROOT "$ENV{HOME}/opt/wasm")
    else ()
        message(FATAL_ERROR "WASM not found and don't know where to look, please specify WASM_ROOT")
    endif ()
endif ()

find_program(WASM_CLANG clang PATHS ${WASM_ROOT}/bin NO_DEFAULT_PATH)
find_program(WASM_LLC llc PATHS ${WASM_ROOT}/bin NO_DEFAULT_PATH)
find_program(WASM_LLVM_LINK llvm-link PATHS ${WASM_ROOT}/bin NO_DEFAULT_PATH)

find_package_handle_standard_args(WASM REQUIRED_VARS WASM_CLANG WASM_LLC WASM_LLVM_LINK)

# find eosio_wasm cmd
if ("${EOSIO_ROOT}" STREQUAL "")
    if (APPLE)
        set(EOSIO_ROOT "/usr/local/eosio")
    elseif (UNIX AND NOT APPLE)
        set(EOSIO_ROOT "$ENV{HOME}/opt/eosio")
    else ()
        message(FATAL_ERROR "EOSIO_ROOT not found and don't know where to look, please specify EOSIO_ROOT")
    endif ()
endif ()

find_program(EOSIO_S2WASM eosio-s2wasm PATHS ${EOSIO_ROOT}/bin NO_DEFAULT_PATH)
find_program(EOSIO_WAST2WASM eosio-wast2wasm PATHS ${EOSIO_ROOT}/bin NO_DEFAULT_PATH)
find_program(EOSIO_ABIGEN eosio-abigen PATHS ${EOSIO_ROOT}/bin NO_DEFAULT_PATH)

find_package_handle_standard_args(EOSIO REQUIRED_VARS EOSIO_S2WASM EOSIO_WAST2WASM EOSIO_ABIGEN)

if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
    set(CMAKE_BUILD_TYPE DEBUG)
endif ()

macro(compile_eosio_wast target)

    foreach (srcfile ${${target}_SOURCES_TO_COMPILE})
        get_filename_component(file ${srcfile} ABSOLUTE)
        get_filename_component(name ${srcfile} NAME)
        get_filename_component(path ${srcfile} PATH)

        set(outname ${path}/${name}.bc)
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/${path})

        set(COMPILE_CMD ${WASM_CLANG} -emit-llvm)
        list(APPEND COMPILE_CMD --std=c++${CMAKE_CXX_STANDARD})
        list(APPEND COMPILE_CMD ${CMAKE_CXX_FLAGS})
        list(APPEND COMPILE_CMD ${CMAKE_WASM_COMPILER_FLAGS})

        string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_U)
        list(APPEND COMPILE_CMD ${CMAKE_WASM_COMPILER_FLAGS_${CMAKE_BUILD_TYPE_U}})

        list(APPEND COMPILE_CMD "$<$<BOOL:$<TARGET_PROPERTY:${target},INTERFACE_COMPILE_DEFINITIONS>>:$<JOIN:$<TARGET_PROPERTY:${target},INTERFACE_COMPILE_DEFINITIONS>,\t>>")
        list(APPEND COMPILE_CMD "$<$<BOOL:$<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>>:-I$<JOIN:$<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>,\t-I>>")

        list(APPEND COMPILE_CMD -c ${file} -o ${outname})

        add_custom_command(OUTPUT ${outname}
                DEPENDS ${file}
                COMMAND ${COMPILE_CMD}
                IMPLICIT_DEPENDS CXX ${file}
                COMMENT "Building LLVM bitcode ${outname}"
                WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
                #VERBATIM
                #COMMAND_EXPAND_LISTS
                )
        set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/${outname} PROPERTIES GENERATED TRUE)
        set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${outname})

        list(APPEND ${target}_outfiles_bc ${outname})
    endforeach ()

    add_custom_target(${target}_compile DEPENDS "${${target}_outfiles_bc}")

endmacro(compile_eosio_wast)

function(link_eosio_wast target)
    # Intermediary directories
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/lib)
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/wasm)
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/wast)
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/abi)

    # Output files
    set(target_lib_file lib/${target}.bc)
    set(target_s_file wast/${target}.s)
    set(target_wast_file wast/${target}.wast)
    set(target_wasm_file wasm/${target}.wasm)


    set(LINK_CMD ${WASM_LLVM_LINK})
    list(APPEND LINK_CMD ${CMAKE_WASM_LINKER_FLAGS})
    list(APPEND LINK_CMD -o ${target_lib_file} ${${target}_outfiles_bc})
    list(APPEND LINK_CMD "$<$<BOOL:$<TARGET_PROPERTY:${target},INTERFACE_LINK_LIBRARIES>>:$<JOIN:$<TARGET_PROPERTY:${target},INTERFACE_LINK_LIBRARIES>,\t>>")

    add_custom_target(generate_${target}.bc DEPENDS "${target_lib_file}")
    add_custom_command(OUTPUT ${target_lib_file}
            DEPENDS "${${target}_outfiles_bc}"
            COMMAND ${LINK_CMD}
            COMMENT "Linking LLVM bitcode executable ${target_lib_file}"
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
            #VERBATIM
            )
    set_source_files_properties(${target_lib_file} PROPERTIES GENERATED TRUE)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${target_lib_file}")

    add_custom_target(generate_${target}.s DEPENDS "${target_s_file}")
    add_custom_command(OUTPUT ${target_s_file}
            DEPENDS ${target_lib_file}
            COMMAND ${WASM_LLC} ${CMAKE_WASM_S_FLAGS} -o ${target_s_file} ${target_lib_file}
            COMMENT "Generating textual assembly ${target}.s"
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
            VERBATIM
            )
    set_source_files_properties(${target_s_file} PROPERTIES GENERATED TRUE)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${target_s_file}")

    add_custom_target(generate_${target}.wast DEPENDS "${target_wast_file}")
    add_custom_command(OUTPUT ${target_wast_file}
            DEPENDS ${target_s_file}
            COMMAND ${EOSIO_S2WASM} -o ${target_wast_file} -s ${CMAKE_WASM_T_FLAGS} ${target_s_file}
            COMMENT "Generating WAST ${target_wast_file}"
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
            VERBATIM
            )
    set_source_files_properties(${target_wast_file} PROPERTIES GENERATED TRUE)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${target_wast_file}")

    add_custom_target(generate_${target}.wasm DEPENDS "${target_wasm_file}")
    add_custom_command(OUTPUT ${target_wasm_file}
            DEPENDS ${target_wast_file}
            COMMAND ${EOSIO_WAST2WASM} ${target_wast_file} ${target_wasm_file} ${CMAKE_WASM_A_FLAGS}
            COMMENT "Generating WASM ${target_wast_file}"
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
            VERBATIM
            )
    set_source_files_properties(${target_wasm_file} PROPERTIES GENERATED TRUE)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${target_wasm_file}")

    add_custom_target(${target}_link DEPENDS "${target_wasm_file}")
endfunction(link_eosio_wast)

function(generate_eosio_abi target)
    #
    foreach (headerfile ${${target}_HEADERS_TO_COMPILE})
        get_filename_component(file ${headerfile} ABSOLUTE)
        get_filename_component(name ${headerfile} NAME_WE)
        get_filename_component(path ${headerfile} PATH)

        set(outname abi/${name}.abi)
        set(context_folder ${CMAKE_CURRENT_SOURCE_DIR}/${path})
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/abi)

        set(COMPILE_CMD ${EOSIO_ABIGEN} -extra-arg=-c -extra-arg=--std=c++14 -extra-arg=--target=wasm32 -extra-arg=-nostdinc -extra-arg=-nostdinc++ -extra-arg=-DABIGEN -extra-arg=-fparse-all-comments)
        list(APPEND COMPILE_CMD "$<$<BOOL:$<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>>:-extra-arg=-I$<JOIN:$<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>,\t-extra-arg=-I>>")
        list(APPEND COMPILE_CMD -destination-file=${outname} -verbose=0 -context=${context_folder} ${file} --)

        add_custom_command(OUTPUT ${outname}
                DEPENDS ${file}
                COMMAND ${COMPILE_CMD}
                IMPLICIT_DEPENDS CXX ${file}
                COMMENT "Generating ABI ${outname}"
                WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir
                #VERBATIM
                #COMMAND_EXPAND_LISTS
                )
        set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/${outname} PROPERTIES GENERATED TRUE)
        set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${outname})

        list(APPEND ${target}_abi_files ${outname})
    endforeach ()

    add_custom_target(${target}_abi_gen DEPENDS "${${target}_abi_files}")

endfunction(generate_eosio_abi)

set(contracts_make_target "contracts")
add_custom_target(${contracts_make_target} ALL)

function(add_eosio_wasm_library target)

    if (${target}_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options CONTRACT IMPORTED INTERFACE)
    set(oneValueArgs "")
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(${target} "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    add_custom_target(${target})
    # IMPORTED
    if (${${target}_IMPORTED})

        set_target_properties(${target} PROPERTIES IMPORTED_TARGET ON)
    else ()

        set_target_properties(${target} PROPERTIES IMPORTED_TARGET OFF)
    endif ()

    # INTERFACE
    if (${${target}_INTERFACE})

        set_target_properties(${target} PROPERTIES INTERFACE_TARGET ON)
    else ()

        set_target_properties(${target} PROPERTIES INTERFACE_TARGET OFF)
    endif ()

    # INTERFACE
    if (${${target}_CONTRACT})

        add_dependencies(${contracts_make_target} ${target})
    endif ()

    # SOURCES : BUILD TARGET
    if (NOT ("${${target}_SOURCES}" STREQUAL ""))

        foreach (src ${${target}_SOURCES})
            list(APPEND ${target}_SOURCES_TO_COMPILE ${src})
        endforeach ()
        list(REMOVE_DUPLICATES ${target}_SOURCES_TO_COMPILE)

        # COMPILE (cpp to llvm bc) -> LINK (link llvm bc, asm, wast, wasm) -> COPY (linked llvm bc, asm, was, wast, wasm)
        compile_eosio_wast(${target})
        link_eosio_wast(${target})
        add_dependencies(${target} ${target}_link)
        file(MAKE_DIRECTORY ${EXECUTABLE_OUTPUT_PATH})
        file(MAKE_DIRECTORY ${LIBRARY_OUTPUT_PATH})
        file(MAKE_DIRECTORY ${CODE_OUTPUT_PATH})
        # OUTPUT TARGET
        add_custom_command(TARGET ${target}
                POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/wasm" .
                WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
                COMMENT "Target ${target} output wasm to ${EXECUTABLE_OUTPUT_PATH}"
                )
        add_custom_command(TARGET ${target}
                POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/lib" .
                WORKING_DIRECTORY ${LIBRARY_OUTPUT_PATH}
                COMMENT "Target ${target} outputllvm bytecode to ${LIBRARY_OUTPUT_PATH}"
                )
        add_custom_command(TARGET ${target}
                POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/wast" .
                WORKING_DIRECTORY ${CODE_OUTPUT_PATH}
                COMMENT "Target ${target} output wast and asm to ${CODE_OUTPUT_PATH}"
                )
    endif ()

    set(${target}_SET ON CACHE INTERNAL "${target}_SET")

endfunction(add_eosio_wasm_library)

function(target_eosio_wasm_compile_definitions target)

    if (${target}_COMPILE_DEF_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs PUBLIC)
    cmake_parse_arguments(${target}_COMPILE_DEFINITIONS "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    if (NOT ("${${target}_COMPILE_DEFINITIONS_PUBLIC}" STREQUAL ""))

        foreach (cpdef ${${target}_COMPILE_DEFINITIONS_PUBLIC})

            set_property(TARGET ${target} APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS ${cpdef})
        endforeach ()
    endif ()

    set(${target}_COMPILE_DEF_SET ON CACHE INTERNAL "${target}_COMPILE_DEF_SET")

endfunction(target_eosio_wasm_compile_definitions)

function(target_eosio_wasm_include_directories target)

    if (${target}_INCLUDES_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs PUBLIC)
    cmake_parse_arguments(${target}_INCLUDE_DIRECTORIES "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    if (NOT ("${${target}_INCLUDE_DIRECTORIES_PUBLIC}" STREQUAL ""))

        foreach (include ${${target}_INCLUDE_DIRECTORIES_PUBLIC})

            set_property(TARGET ${target} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${include})
        endforeach ()
    endif ()

    set(${target}_INCLUDES_SET ON CACHE INTERNAL "${target}_INCLUDES_SET")

endfunction(target_eosio_wasm_include_directories)

function(set_eosio_wasm_target_properties target)

    if (${target}_PROPERTIES_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options PROPERTIES)
    set(oneValueArgs IMPORTED_LOCATION)
    set(multiValueArgs INCLUDE_DIRECTORIES)
    cmake_parse_arguments(${target}_PROPERTIES "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    get_target_property(${target}_IMPORTED "${target}" IMPORTED_TARGET)
    if (${${target}_IMPORTED})

        set_target_properties(${target} PROPERTIES IMPORTED_LOCATION ${${target}_PROPERTIES_IMPORTED_LOCATION})
    endif ()

    if (NOT ("${${target}_PROPERTIES_INCLUDE_DIRECTORIES}" STREQUAL ""))

        foreach (include ${${target}_PROPERTIES_INCLUDE_DIRECTORIES})

            set_property(TARGET ${target} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${include})
            include_directories(${include})
        endforeach ()
    endif ()

    set(${target}_PROPERTIES_SET ON CACHE INTERNAL "${target}_PROPERTIES_SET")

endfunction(set_eosio_wasm_target_properties)


function(target_eosio_wasm_link_libraries target)

    if (${target}_LIBRARIES_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs "")
    cmake_parse_arguments(${target}_LIBRARIES "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    foreach (library ${ARGN})
        get_target_property(${library}_IMPORTED ${library} IMPORTED_TARGET)
        get_target_property(${library}_INTERFACE ${library} INTERFACE_TARGET)
        get_target_property(${library}_INCLUDE_DIRECTORIES ${library} INTERFACE_INCLUDE_DIRECTORIES)

        if (${${library}_IMPORTED})

            get_target_property(${library}_IMPORTED_LOCATION ${library} IMPORTED_LOCATION)

            if (NOT ("${${library}_IMPORTED_LOCATION}" MATCHES ".*-NOTFOUND"))

                set_property(TARGET ${target} APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${${library}_IMPORTED_LOCATION})

            endif ()
        elseif (NOT ${${library}_INTERFACE})

            #  build dependancy
            add_dependencies(${target} ${library})
        endif ()

        # library declares interface
        if (NOT ("${${library}_INCLUDE_DIRECTORIES}" MATCHES ".*-NOTFOUND"))

            foreach (include ${${library}_INCLUDE_DIRECTORIES})

                set_property(TARGET ${target} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${include})
            endforeach ()
        endif ()

    endforeach ()

    set(${target}_LIBRARIES_SET ON CACHE INTERNAL "${target}_LIBRARIES_SET")

endfunction(target_eosio_wasm_link_libraries)

function(add_eosio_wasm_abi target)
    if (${target}_ABI_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs HEADERS)
    cmake_parse_arguments(${target} "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    # SOURCES
    if (NOT ("${${target}_HEADERS}" STREQUAL ""))

        foreach (header ${${target}_HEADERS})
            list(APPEND ${target}_HEADERS_TO_COMPILE ${header})
        endforeach ()
        list(REMOVE_DUPLICATES ${target}_HEADERS_TO_COMPILE)

        generate_eosio_abi(${target})
        add_dependencies(${target} ${target}_abi_gen)
        # GENERATE (hpp to abi) -> COPY ABI
        file(MAKE_DIRECTORY ${ABI_OUTPUT_PATH})
        add_custom_command(TARGET ${target}
                POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${target}.dir/abi" .
                WORKING_DIRECTORY ${ABI_OUTPUT_PATH}
                COMMENT "Target ${target} output abi to ${ABI_OUTPUT_PATH}"
                )
    endif ()

    set(${target}_ABI_SET ON CACHE INTERNAL "${target}_ABI_SET")

endfunction(add_eosio_wasm_abi)

function(eosio_wasm_install target)
    if (${target}_INSTALL_SET)
        # CACHE ALREADY POPULATED
    endif ()

    set(options CONTRACT LIBRARY)
    set(oneValueArgs "")
    set(multiValueArgs INTERFACE RUNTIME CODE ABI)
    cmake_parse_arguments(${target}_INSTALL "${options}" "${oneValueArgs}"
            "${multiValueArgs}" ${ARGN})

    add_custom_target(${target}_install)
    add_dependencies(${target}_install ${target})

    # INSTALL CONTRACT TARGET
    if (${${target}_INSTALL_CONTRACT})
        if (NOT ("${${target}_INSTALL_ABI}" STREQUAL ""))
            cmake_parse_arguments(${target}_INSTALL_ABI "" "DESTINATION"
                    "" ${${target}_INSTALL_ABI})
            # COPY abi
            add_custom_command(TARGET ${target}_install
                    POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E echo "${ABI_OUTPUT_PATH}:${${target}_INSTALL_ABI_DESTINATION}"
                    COMMAND ${CMAKE_COMMAND} -E copy ${target}.abi "${${target}_INSTALL_ABI_DESTINATION}/${target}.abi"
                    WORKING_DIRECTORY "${ABI_OUTPUT_PATH}"
                    COMMENT "Installing contracts abi"
                    )
        endif ()
        if (NOT ("${${target}_INSTALL_CODE}" STREQUAL ""))
            cmake_parse_arguments(${target}_INSTALL_CODE "" "DESTINATION"
                    "" ${${target}_INSTALL_CODE})
            # COPY wasm
            add_custom_command(TARGET ${target}_install
                    POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E echo "${EXECUTABLE_OUTPUT_PATH}:${${target}_INSTALL_CODE_DESTINATION}"
                    COMMAND ${CMAKE_COMMAND} -E copy ${target}.wasm "${${target}_INSTALL_CODE_DESTINATION}/${target}.wasm"
                    WORKING_DIRECTORY "${EXECUTABLE_OUTPUT_PATH}"
                    COMMENT "Installing contracts wasm"
                    )
            # COPY wast
            add_custom_command(TARGET ${target}_install
                    POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E echo "${CODE_OUTPUT_PATH}:${${target}_INSTALL_CODE_DESTINATION}"
                    COMMAND ${CMAKE_COMMAND} -E copy ${target}.wast "${${target}_INSTALL_CODE_DESTINATION}/${target}.wast"
                    WORKING_DIRECTORY "${CODE_OUTPUT_PATH}"
                    COMMENT "Installing contracts wast"
                    )
        endif ()
    endif ()
    # INSTALL LIBRARY TARGET
    if (${${target}_INSTALL_LIBRARY})
        if (NOT ("${${target}_INSTALL_LIBRARY_CODE}" STREQUAL ""))
            cmake_parse_arguments(${target}_INSTALL_LIBRARY_CODE "" "DESTINATION"
                    "" ${${target}_INSTALL_LIBRARY_CODE})
            # COPY bc files
            add_custom_command(TARGET ${target}_install
                    POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E echo "${LIBRARY_OUTPUT_PATH}:${${target}_INSTALL_LIBRARY_CODE_DESTINATION}"
                    COMMAND ${CMAKE_COMMAND} -E copy ${target}.bc "${${target}_INSTALL_LIBRARY_CODE_DESTINATION}/${target}.bc"
                    WORKING_DIRECTORY "${LIBRARY_OUTPUT_PATH}"
                    COMMENT "Installing contracts bytecode library"
                    )
        endif ()
        if (NOT ("${${target}_INSTALL_LIBRARY_RUNTIME}" STREQUAL ""))
            cmake_parse_arguments(${target}_INSTALL_LIBRARY_RUNTIME "" "DESTINATION"
                    "" ${${target}_INSTALL_LIBRARY_RUNTIME})
            # COPY wasm files
            add_custom_command(TARGET ${target}_install
                    POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E echo "${EXECUTABLE_OUTPUT_PATH}:${${target}_INSTALL_LIBRARY_RUNTIME_DESTINATION}"
                    COMMAND ${CMAKE_COMMAND} -E copy ${target}.wasm "${${target}_INSTALL_LIBRARY_RUNTIME_DESTINATION}/${target}.wasm"
                    WORKING_DIRECTORY "${EXECUTABLE_OUTPUT_PATH}"
                    COMMENT "Installing runtime wasm"
                    )
        endif ()
    endif ()

    set(${target}_INSTALL_SET ON CACHE INTERNAL "${target}_INSTALL_SET")
endfunction(eosio_wasm_install)
