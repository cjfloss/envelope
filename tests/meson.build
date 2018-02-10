message('Running tests...')

configure_file(input : 'sample.qif',
  output : 'sample.qif',
  configuration : configuration_data())

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

    dependencies : [
        dependency('glib-2.0', version :'>=2.29.0'),
        dependency('gtk+-3.0', version :'>=3.14'),
        dependency('gobject-2.0'),
        dependency('gee-0.8'),
        dependency('granite', version :'>=0.3.0'),
        dependency('sqlheavy-0.1'),
        dependency('gio-2.0'),
        meson.get_compiler('vala').find_library('posix'),
        meson.get_compiler('c').find_library('m', required : false)
    ],
    install : false)

test('importTest', importT)
