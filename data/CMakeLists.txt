include(GSettings)
add_schema("org.envelope.settings.gschema.xml")

install (FILES envelope.desktop DESTINATION ${DATADIR}/applications/)
