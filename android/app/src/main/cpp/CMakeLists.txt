cmake_minimum_required(VERSION 3.18.1)
project("bitnet" C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR ANDROID_ABI STREQUAL "arm64-v8a")
    add_compile_definitions(__ARM_NEON)
    add_compile_options(-O3 -fvectorize)
endif()

add_library(bitnet SHARED
    bitnet_kernel.cpp
    bitnet_engine.cpp
    bitnet_ffi.cpp
)

find_library(log-lib log)
find_library(m-lib m)

target_link_libraries(bitnet
    ${log-lib}
    ${m-lib}
)
