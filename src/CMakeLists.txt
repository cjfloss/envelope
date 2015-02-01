find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED
  glib-2.0>=2.29.0
  gtk+-3.0
  gee-0.8
  granite>=0.3.0
  sqlheavy-0.1
  gio-2.0
)

configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/src/config.h)

add_definitions(${DEPS_CFLAGS})
add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")
add_definitions (${CC_OPTS})

link_libraries(${DEPS_LIBRARIES} "m")
link_directories(${DEPS_LIBRARY_DIRS})

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}

  util/String.vala
  util/Date.vala

  model/Account.vala
  model/Budget.vala
  model/Transaction.vala
  model/Category.vala
  model/MonthlyCategory.vala
  model/Merchant.vala

  database/Database.vala

  service/Error.vala
  service/AccountManager.vala
  service/BudgetManager.vala
  service/Importer.vala
  service/QIFImporter.vala
  service/MerchantStore.vala
  service/CategoryStore.vala

  service/settings/SavedState.vala

  view/TransactionView.vala
  view/Sidebar.vala
  view/WelcomeScreen.vala
  view/AccountWelcomeScreen.vala
  view/BudgetOverview.vala
  view/FilterView.vala
  view/CategoryProperties.vala

  window/MainWindow.vala

  dialog/AbstractDialog.vala
  dialog/AddAccountDialog.vala
  dialog/AddCategoryDialog.vala
  dialog/ImportTransactionsDialog.vala

  widget/AbstractPopoverCellRenderer.vala
  widget/CellRendererDatePicker.vala
  widget/CellRendererTextCompletion.vala
  widget/CellRendererCategoryPicker.vala
  widget/CellRendererUpdatable.vala
  widget/CellRendererPopoverContainer.vala

  Envelope.vala

  PACKAGES
    gtk+-3.0
    glib-2.0
    gee-0.8
    sqlheavy-0.1
    gio-2.0
    granite>=0.3.0

  CUSTOM_VAPIS
    vapi/monetary.vapi
    vapi/config.vapi

  GENERATE_VAPI
    ${EXEC_NAME}
)

add_executable("${EXEC_NAME}" ${VALA_C})

install (TARGETS "${EXEC_NAME}" RUNTIME DESTINATION bin)
