
project (envelope)

cmake_minimum_required (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

set (PROGRAM_NAME "envelope")
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.vala)
set (PKGDATADIR "${DATADIR}/envelope")
set (EXEC_NAME "envelope")
set (RELEASE_NAME "An easy to use personal budget application.")
set (VERSION "0.0.0")
set (VERSION_INFO "development")
set (GETTEXT_PACKAGE "envelope")

configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED
  glib-2.0>=2.29.0
  gtk+-3.0
  gee-0.8
  granite>=0.3.0
  sqlheavy-0.1
  gio-2.0
)

add_definitions(${DEPS_CFLAGS})
add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)

include(ValaVersion)

ensure_vala_version("0.16" MINIMUM)

include(ValaPrecompile)

vala_precompile(VALA_C ${EXEC_NAME}

  src/util/string.vala

  src/model/Account.vala
  src/model/Budget.vala
  src/model/Transaction.vala
  src/model/Category.vala
  src/model/Merchant.vala

  src/database/Database.vala

  src/service/Error.vala
  src/service/AccountManager.vala
  src/service/BudgetManager.vala
  src/service/Importer.vala
  src/service/QIFImporter.vala
  src/service/MerchantStore.vala

  src/service/settings/SavedState.vala

  src/view/TransactionView.vala
  src/view/Sidebar.vala
  src/view/WelcomeScreen.vala
  src/view/AccountWelcomeScreen.vala
  src/view/BudgetOverview.vala
  src/view/FilterView.vala

  src/window/MainWindow.vala

  src/dialog/AddAccountDialog.vala

  src/widget/CellRendererDatePicker.vala
  src/widget/CellRendererTextCompletion.vala

  src/Envelope.vala

  PACKAGES
    gtk+-3.0
    glib-2.0
    gee-0.8
    sqlheavy-0.1
    gio-2.0
    granite>=0.3.0

  CUSTOM_VAPIS
    src/vapi/monetary.vapi
    src/vapi/config.vapi
)

add_executable(${EXEC_NAME} ${VALA_C})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/envelope.desktop DESTINATION ${DATADIR}/applications/)
