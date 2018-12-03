gnome = import ('gnome')
i18n  = import ('i18n')

icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
  install_data (
    join_paths ('icons', i, 'com.github.cjfloss.envelope.svg'),
    install_dir: join_paths ( get_option ('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
  )
endforeach

install_data (
    meson.project_name () + '.gschema.xml',
    install_dir : join_paths (get_option ('datadir'), 'glib-2.0', 'schemas')
)
meson.add_install_script ('post_install.py')

i18n.merge_file (
    'desktop',
    input : app_name + '.desktop.in',
    output : app_name + '.desktop',
    install : true,
    install_dir : join_paths (get_option ('datadir'), 'applications'),
    po_dir : join_paths (meson.source_root (), 'po'),
    type : 'desktop'
)

i18n.merge_file (
    'appdata',
    input : app_name + '.appdata.xml.in',
    output : app_name + '.appdata.xml',
    install : true,
    install_dir : join_paths (get_option ('datadir'), 'metainfo'),
    po_dir : join_paths (meson.source_root (), 'po')
)

dvf = find_program('desktop-file-validate', required: false)
if dvf.found()
test (
    'Validate desktop file',
    dvf,
    args : join_paths (meson.current_build_dir (), meson.project_name () + '.desktop')
)
endif

asc = find_program('appstreamcli', required : false)
if asc.found()
test (
   'Validate appdata file',
    asc,
    args : ['validate', join_paths (meson.current_build_dir (), meson.project_name () + '.appdata.xml')]
)
endif

vala_lint = find_program ('io.elementary.vala-lint', required: false)
if vala_lint.found()
  test (
    'Vala lint',
    vala_lint,
    args: ['-d', join_paths (meson.source_root (), 'src')]
  )
endif
