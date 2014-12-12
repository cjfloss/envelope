static int main (string[] args) {
    Gtk.init (ref args);

    var app = new Envelope.App ();

    return app.run (args);
}
