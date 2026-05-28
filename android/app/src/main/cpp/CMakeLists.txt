cmake_minimum_required(VERSION 3.22.1)

project(soratunbridge)

add_library(soratunbridge SHARED soratun_bridge.cpp)

find_library(log-lib log)

target_link_libraries(
    soratunbridge
    ${log-lib}
    dl
)
