
project (envelope)

cmake_minimum_required (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Get the current working branch
execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Get the latest abbreviated commit hash of the working branch
execute_process(
    COMMAND git log -1 --format=%h
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PROGRAM_NAME "envelope")
set (USER_PROGRAM_NAME "Envelope")
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.vala)
set (PKGDATADIR "${DATADIR}/envelope")
set (EXEC_NAME "envelope")
set (EXEC_NAME_TESTS "envelope-tests")
set (RELEASE_NAME "An easy to use personal budget application.")
set (VERSION "0.0.0")
set (VERSION_INFO "git-${GIT_BRANCH}-${GIT_COMMIT_HASH}")
set (GETTEXT_PACKAGE "envelope")
set (CC_OPTS "-w")

add_subdirectory (data)
add_subdirectory (src)
add_subdirectory (tests)
