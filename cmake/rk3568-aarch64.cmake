cmake_minimum_required(VERSION 3.21)
include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# CMake re-runs this toolchain file inside try_compile() projects.  Explicitly
# forward our custom cache variables so compiler ABI checks see the same
# target sysroot and compiler tuple as the parent configure step.
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RK3568_SYSROOT RK3568_TRIPLE RK3568_QT_HOST_MOC)

if(NOT RK3568_SYSROOT AND DEFINED ENV{RK3568_SYSROOT})
    set(RK3568_SYSROOT "$ENV{RK3568_SYSROOT}")
endif()
if(NOT RK3568_SYSROOT AND CMAKE_SYSROOT)
    set(RK3568_SYSROOT "${CMAKE_SYSROOT}")
endif()
set(RK3568_SYSROOT "" CACHE PATH "RK3568 target sysroot (set by the entrypoint)")
if(NOT RK3568_SYSROOT)
    message(FATAL_ERROR "RK3568_SYSROOT must be set to the target sysroot")
endif()
set(RK3568_TRIPLE "aarch64-linux-gnu" CACHE STRING "target compiler tuple")
set(CMAKE_SYSROOT "${RK3568_SYSROOT}")

# Qt/GLib and other shared libraries have transitive dependencies.  Tell ld
# where to resolve those DT_NEEDED entries inside the target sysroot instead
# of falling back to the build host's cross libraries.
set(_RK3568_SYSROOT_LINK_DIRS
    "${CMAKE_SYSROOT}/lib/aarch64-linux-gnu"
    "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu")
set(_RK3568_RPATH_LINK_FLAGS "")
foreach(_dir IN LISTS _RK3568_SYSROOT_LINK_DIRS)
    string(APPEND _RK3568_RPATH_LINK_FLAGS " -Wl,-rpath-link,${_dir} -L${_dir}")
endforeach()
set(CMAKE_EXE_LINKER_FLAGS_INIT "${_RK3568_RPATH_LINK_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_RK3568_RPATH_LINK_FLAGS}")

set(CMAKE_C_COMPILER "${RK3568_TRIPLE}-gcc")
set(CMAKE_CXX_COMPILER "${RK3568_TRIPLE}-g++")
set(CMAKE_AR "${RK3568_TRIPLE}-ar")
set(CMAKE_RANLIB "${RK3568_TRIPLE}-ranlib")
set(CMAKE_STRIP "${RK3568_TRIPLE}-strip")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${CMAKE_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR}
    "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")

set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
