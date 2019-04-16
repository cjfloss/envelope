project (
  'com.github.cjfloss.envelope', 'vala', 'c',
  version: '0.0.4',
  license: 'GPL3',
  meson_version: '>= 0.47.0',
  default_options: ['warning_level=3']
)

add_global_arguments (
  '-DGETTEXT_PACKAGE="' + meson.project_name () + '"',
  language: 'c'
)

i18n = import ('i18n')
gnome = import ('gnome')

subdir ('src')
subdir ('data')
subdir ('po')
subdir ('tests')