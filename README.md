# eosio-cmake

CMake scripts for eosio smart contract developments.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#Prerequisites)
- [How it works](#how-it-works)
  - [CMake function extension](#cmake-function-extension)
  - [CMake configuration extension](#cmake-configuration-extension)
  - [CMake EOSIO sdk imports](#cmake-eosio-sdk-imports)
- [Usage](#usage)
  - [Using scripts from your project](#using-scripts-from-your-project)
  - [Build from cmake](#build-from-cmake)
  - [CLion introspection hack](#clion-introspection-hack)
- [Example](#example)
- [License](#license)

## Overview

This project provides cmake scripts and attempts to mimic CMake build patterns while targeting eosio wasm compiler. Altough a cross compiler would be the ultimate solution, here we provide a simple approache based on cmake scripts.

Compared to other scripting solution, this project allows you to work within an IDE compatible with cmake (eg Clion)

## Prerequisites

You must already have installed eosio headers, libraries and executables before using the following scripts. Please [install eosio](https://developers.eos.io). When looking for headers, libraries and executables variables default search dir is `/usr/local` on macosx and `$ENV{HOME}/opt/` on other unix systems (scripts have not been tested on other systems other than macosx).

## How it works

We provide three scripts `eosiosdk.cmake` `eosiosdk-util.cmake` `FindEOSIOSDKLibs.cmake`.

### CMake function extension

`eosiosdk.cmake` define cmake function similar to `add_library` `target_compile_definitions` `target_include_directories` `target_link_libraries` 
and a new function specific to eosio `add_eosio_wasm_abi`.

 - add_eosio_wasm_library: defined as `function(add_eosio_wasm_library target)`
 - target_eosio_wasm_compile_definitions: defined as `function(target_eosio_wasm_compile_definitions target)`
 - target_eosio_wasm_include_directories: defined as `function(target_eosio_wasm_include_directories target)`
 - target_eosio_wasm_link_libraries: defined as `function(target_eosio_wasm_link_libraries target)`
 
### CMake configuration extension
`eosiosdk-util.cmake` define CMake configuration flags and WASM compiler flags.

Available options are:
- LIBRARY_OUTPUT_PATH default :${PROJECT_BINARY_DIR}/lib
- EXECUTABLE_OUTPUT_PATH default :${PROJECT_BINARY_DIR}/bin
- CODE_OUTPUT_PATH default :${PROJECT_BINARY_DIR}/code
- ABI_OUTPUT_PATH default :${PROJECT_BINARY_DIR}/abi
- INSTALL_CODEDIR default: code
- INSTALL_ABIDIR default: abi
- INSTALL_FULL_CODEDIR default: ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_CODEDIR}
- INSTALL_FULL_ABIDIR default: ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_ABIDIR}
- WASM_COMPILER_FLAGS_RELEASE default: -O3
- WASM_COMPILER_FLAGS default: --target=wasm32 -nostdinc -nostdlib -nostdlibinc -ffreestanding -nostdlib -fno-threadsafe-statics -fno-rtti -fno-exceptions
- WASM_LINKER_FLAGS default: -only-needed
- WASM_S_FLAGS default: -thread-model=single -asm-verbose=false
- WASM_T_FLAGS default: 16384
- WASM_A_FLAGS default: -n
- EOSIO_ROOT default: /usr/local/eosio
- WASM_ROOT default: /usr/local/wasm

### CMake EOSIO sdk imports
`FindEOSIOSDKLibs.cmake` defines and imports eosio headers and wasm libraries as targets.

### Targets and dependencies
- Build targets and dependencies
`eosiosdk` defines a build root target named `contracts`. Project target are added as dependencies to `contracts` target.
Each target defines the following depency tree:
 ```${target}
    ├── ${target}_abi_gen                                  # output abi
    ├── ${target}_link                                  
    |      ├── generate_${target}.bc                       # output build and link llvm byte code
    |           ├── generate_${target}.s                   # output llc assembly text
    |                ├── generate_${target}.wast           # output WAST file
    |                ├── generate_${target}.wasm           # output target WASM file
    └── ${target}_install 
```

## Usage

### Using scripts from your project
Copy `eosiosdk.cmake`, `eosiosdk-util.cmake`, `FindEOSIOSDKLibs` and add them in your root CMakeLists.

```
include(cmake/eosiosdk.cmake)
include(cmake/eosiosdk-util.cmake)
include(cmake/FindEOSIOSDKLibs.cmake)
```
### Build from cmake

Your projects build like a normal cmake project
- building
```
cd your-project
mkdir build && cd build
cmake ..
make contracts
```

This scripts should create an abi, code and lib directories each containing abi, wast/wasm code and byte code libraries for each targets defined in your project.

- installing
```
make ${target_contract}_install 
```

### CLion introspection hack

To enable clion code introspection use the following hack.

```
add_library(eosio_hello_world.tmp ${${PROJECT_NAME}_SOURCES})
target_include_directories(eosio_hello_world.tmp
        PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        PRIVATE
        $<TARGET_PROPERTY:eosio,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:libc++,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:libc,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:musl,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:Boost,INTERFACE_INCLUDE_DIRECTORIES>
        )
```
## Example 

An example Clion project with 3 eos smart contract [eosio-cmake-examples](https://github.com/awalga/eosio-cmake-examples/)

## License

MIT
