cmake_minimum_required(VERSION 3.21)
project(hello_rk3568 LANGUAGES CXX)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets)

set(RK3568_QT_HOST_MOC "" CACHE FILEPATH "Native host moc executable for cross compilation")
if(RK3568_QT_HOST_MOC)
    if(NOT EXISTS "${RK3568_QT_HOST_MOC}")
        message(FATAL_ERROR "RK3568_QT_HOST_MOC does not exist: ${RK3568_QT_HOST_MOC}")
    endif()
    set(Qt5Core_MOC_EXECUTABLE "${RK3568_QT_HOST_MOC}")
    set_property(TARGET Qt5::moc PROPERTY IMPORTED_LOCATION "${RK3568_QT_HOST_MOC}")
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

add_executable(hello-rk3568 main.cpp)
target_link_libraries(hello-rk3568 PRIVATE Qt5::Core Qt5::Gui Qt5::Widgets)
