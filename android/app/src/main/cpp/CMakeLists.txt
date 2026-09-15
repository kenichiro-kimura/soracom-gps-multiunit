cmake_minimum_required(VERSION 3.22.1)

project(soratunbridge)

add_library(soratunbridge SHARED soratun_bridge.cpp)

target_link_options(soratunbridge PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,-z,common-page-size=16384"
)

find_library(log-lib log)

target_link_libraries(
    soratunbridge
    ${log-lib}
    dl
)
