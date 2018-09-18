################################
# eosio include create an interface lib
################################
# set eosio library
add_eosio_wasm_library(eosio IMPORTED)
set_eosio_wasm_target_properties(eosio PROPERTIES
        IMPORTED_LOCATION /usr/local/eosio/usr/share/eosio/contractsdk/lib/eosiolib.bc # .bc
        INCLUDE_DIRECTORIES /usr/local/eosio/include
        )

# set libc++ library
add_eosio_wasm_library(libc++ IMPORTED)
set_eosio_wasm_target_properties(libc++ PROPERTIES
        IMPORTED_LOCATION /usr/local/eosio/usr/share/eosio/contractsdk/lib/libc++.bc # .bc
        INCLUDE_DIRECTORIES /usr/local/eosio/include/libc++/upstream/include
        )

# set libc library
add_eosio_wasm_library(libc IMPORTED)
set_eosio_wasm_target_properties(libc PROPERTIES
        IMPORTED_LOCATION /usr/local/eosio/usr/share/eosio/contractsdk/lib/libc.bc # .bc
        )

# set musl interface
add_eosio_wasm_library(musl INTERFACE)
set_eosio_wasm_target_properties(musl PROPERTIES
        INCLUDE_DIRECTORIES /usr/local/eosio/include/musl/upstream/include
        )

# find boost dependencies
find_package(Boost REQUIRED)
# set Boost interface
add_eosio_wasm_library(Boost INTERFACE)
set_eosio_wasm_target_properties(Boost PROPERTIES
        INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS}
        )
