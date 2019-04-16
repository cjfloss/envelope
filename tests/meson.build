message ('Configuring tests…')

configure_file (
  input: 'sample.qif',
  output: 'sample.qif',
  copy: true
)

importT = executable (
  'importTest',
  meson.source_root () + '/src/vapi/monetary.vapi',
  meson.source_root () + '/src/util/String.vala',
  meson.source_root () + '/src/util/Date.vala',

  meson.source_root () + '/src/model/Account.vala',
  meson.source_root () + '/src/model/Transaction.vala',
  meson.source_root () + '/src/model/Category.vala',

  meson.source_root () + '/src/service/Error.vala',
  meson.source_root () + '/src/service/Importer.vala',
  meson.source_root () + '/src/service/QIFImporter.vala',

  'QIFImporterTest.vala',

  dependencies: [
    dependency ('glib-2.0', version: '>= 2.29.0'),
    dependency ('gee-0.8'),
    dependency ('gio-2.0'),
  ],
  install: false
)

test ('Import QIF files', importT)
