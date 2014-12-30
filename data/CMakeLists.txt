include(GSettings)
add_schema("org.envelope.envelope.gschema.xml")

install (FILES envelope.desktop DESTINATION ${DATADIR}/applications/)
