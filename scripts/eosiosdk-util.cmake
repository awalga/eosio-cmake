if ("${LIBRARY_OUTPUT_PATH}" STREQUAL "")
    set(LIBRARY_OUTPUT_PATH ${PROJECT_BINARY_DIR}/lib)
endif ()

if ("${EXECUTABLE_OUTPUT_PATH}" STREQUAL "")
    set(EXECUTABLE_OUTPUT_PATH ${PROJECT_BINARY_DIR}/bin)
endif ()

if ("${CODE_OUTPUT_PATH}" STREQUAL "")
    set(CODE_OUTPUT_PATH ${PROJECT_BINARY_DIR}/code)
endif ()

if ("${ABI_OUTPUT_PATH}" STREQUAL "")
    set(ABI_OUTPUT_PATH ${PROJECT_BINARY_DIR}/abi)
endif ()

if ("${CMAKE_INSTALL_CODEDIR}" STREQUAL "")
    set(CMAKE_INSTALL_CODEDIR code)
endif ()

if ("${CMAKE_INSTALL_ABIDIR}" STREQUAL "")
    set(CMAKE_INSTALL_ABIDIR abi)
endif ()

if ("${CMAKE_INSTALL_FULL_CODEDIR}" STREQUAL "")
    set(CMAKE_INSTALL_FULL_CODEDIR ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_CODEDIR})
endif ()

if ("${CMAKE_INSTALL_FULL_ABIDIR}" STREQUAL "")
    set(CMAKE_INSTALL_FULL_ABIDIR ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_ABIDIR})
endif ()

if ("${CMAKE_WASM_COMPILER_FLAGS_RELEASE}" STREQUAL "")
    set(CMAKE_WASM_COMPILER_FLAGS_RELEASE -O3)
endif ()

if ("${CMAKE_WASM_COMPILER_FLAGS}" STREQUAL "")
    set(CMAKE_WASM_COMPILER_FLAGS --target=wasm32 -nostdinc -nostdlib -nostdlibinc -ffreestanding -nostdlib -fno-threadsafe-statics -fno-rtti -fno-exceptions)
endif ()

if ("${CMAKE_WASM_LINKER_FLAGS}" STREQUAL "")
    set(CMAKE_WASM_LINKER_FLAGS -only-needed)
endif ()

if ("${CMAKE_WASM_S_FLAGS}" STREQUAL "")
    set(CMAKE_WASM_S_FLAGS -thread-model=single -asm-verbose=false)
endif ()

if ("${CMAKE_WASM_T_FLAGS}" STREQUAL "")
    set(CMAKE_WASM_T_FLAGS 16384)

endif ()

if ("${CMAKE_WASM_A_FLAGS}" STREQUAL "")
    set(CMAKE_WASM_A_FLAGS -n)
endif ()

