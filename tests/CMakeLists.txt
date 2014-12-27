find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED
  glib-2.0>=2.29.0
  gtk+-3.0
  gee-0.8
  granite>=0.3.0
  sqlheavy-0.1
  gio-2.0
)

find_package(Vala REQUIRED)

include(ValaVersion)
ensure_vala_version("0.23.2" MINIMUM)

include(ValaPrecompile)
enable_testing ()

add_definitions(${DEPS_CFLAGS})
add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")
add_definitions (${CC_OPTS})

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

set (LIBS ${LIBS} envelope-clib)

vala_precompile (VALA_C_TEST ${EXEC_NAME_TESTS}

  ../src/util/String.vala
  ../src/util/Date.vala

  ../src/model/Account.vala
  ../src/model/Transaction.vala
  ../src/model/Category.vala

  ../src/service/Error.vala
  ../src/service/Importer.vala
  ../src/service/QIFImporter.vala

  QIFImporterTest.vala

  PACKAGES
    gtk+-3.0
    glib-2.0
    gee-0.8
    sqlheavy-0.1
    gio-2.0
    granite>=0.3.0

  CUSTOM_VAPIS
    ../src/vapi/monetary.vapi
    ../src/vapi/config.vapi
    #${CMAKE_BINARY_DIR}/src/envelope.vapi
)

add_executable(${EXEC_NAME_TESTS} ${VALA_C_TEST})
add_test (${EXEC_NAME_TESTS} ${CMAKE_CURRENT_BINARY_DIR}/envelope-tests)
