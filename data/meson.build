gnome = import ('gnome')
i18n  = import ('i18n')

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

test (
    'Validate desktop file',
    find_program ('desktop-file-validate'),
    args : join_paths (meson.current_build_dir (), app_name + '.desktop')
)

test (
    'Validate appdata file',
    find_program ('appstreamcli'),
    args : ['validate', join_paths (meson.current_build_dir (), app_name + '.appdata.xml')]
)
