
project (envelope)

cmake_minimum_required (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

set (PROGRAM_NAME "envelope")
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.vala)
set (PKGDATADIR "${DATADIR}/envelope")
set (EXEC_NAME "envelope")
set (EXEC_NAME_TESTS "envelope-tests")
set (RELEASE_NAME "An easy to use personal budget application.")
set (VERSION "0.0.0")
set (VERSION_INFO "development")
set (GETTEXT_PACKAGE "envelope")
set (CC_OPTS "-w")

add_subdirectory (data)
add_subdirectory (src)
add_subdirectory (tests)
