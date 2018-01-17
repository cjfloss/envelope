project('com.github.cjfloss.envelope', 'vala', 'c')

i18n = import('i18n')

datagit = run_command('git', 'rev-parse', '--abbrev-ref', 'HEAD')
datagithash = run_command('git','log', '-1', '--format=%h')

app_name = meson.project_name()
short_name = 'envelope'
version = '0.0.0'
git_branch = datagit.stdout().strip()
git_commit_hash = datagithash.stdout().strip()
version_info = 'git-' + git_branch + '-' + git_commit_hash
release_name = 'alpha'
prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
pkg_datadir = join_paths(datadir, short_name)

add_global_arguments('-DGETTEXT_PACKAGE="' + meson.project_name() + '"',language : 'c')

config = configuration_data()
config.set('app_name', app_name)
config.set('datadir', datadir)
config.set('pkg_datadir', pkg_datadir)
config.set('gettext_package', app_name)
config.set('release_name', release_name)
config.set('version', version)
config.set('version_info', version_info)
config.set('git_branch', git_branch)
config.set('git_commit_hash', git_commit_hash)

build_config = configure_file(input : 'Build.vala', output: 'Build.vala', configuration: config)

join_paths(meson.build_root(), '@0@'.format(build_config))

executable(
    meson.project_name(),
    'src/vapi/monetary.vapi',
    join_paths(meson.build_root(), 'Build.vala'),

    'src/util/String.vala',
    'src/util/Date.vala',

    'src/model/Account.vala',
    'src/model/Budget.vala',
    'src/model/Transaction.vala',
    'src/model/Category.vala',
    'src/model/MonthlyCategory.vala',
    'src/model/Merchant.vala',

    'src/database/Database.vala',

    'src/service/Error.vala',
    'src/service/AccountManager.vala',
    'src/service/BudgetManager.vala',
    'src/service/Importer.vala',
    'src/service/QIFImporter.vala',
    'src/service/MerchantStore.vala',
    'src/service/CategoryStore.vala',
    'src/service/settings/SavedState.vala',

    'src/view/TransactionView.vala',
    'src/view/Sidebar.vala',
    'src/view/WelcomeScreen.vala',
    'src/view/AccountWelcomeScreen.vala',
    'src/view/BudgetOverview.vala',
    'src/view/FilterView.vala',
    'src/view/CategoryProperties.vala',

    'src/dialog/AbstractDialog.vala',
    'src/dialog/AddAccountDialog.vala',
    'src/dialog/AddCategoryDialog.vala',
    'src/dialog/ImportTransactionsDialog.vala',

    'src/widget/AbstractPopoverCellRenderer.vala',
    'src/widget/CellRendererDatePicker.vala',
    'src/widget/CellRendererTextCompletion.vala',
    'src/widget/CellRendererCategoryPicker.vala',
    'src/widget/CellRendererUpdatable.vala',
    'src/widget/CellRendererPopoverContainer.vala',

    'src/window/MainWindow.vala',

    'src/Envelope.vala',

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
    install : true
)

subdir('data')
subdir('tests')
