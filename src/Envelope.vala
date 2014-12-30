/* Copyright 2014 Nicolas Laplante
*
* This file is part of envelope.
*
* envelope is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* envelope is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with envelope. If not, see http://www.gnu.org/licenses/.
*/

using Envelope.Window;

private Envelope.App application_instance = null;

public class Envelope.App : Granite.Application {

    public const string PROGRAM_NAME = "Envelope";
    public const int TOAST_TIMEOUT = 3000;

    construct {
        // This allows opening files. See the open() method below.
        flags |= ApplicationFlags.HANDLES_OPEN;

        // App info
        build_data_dir = Build.DATADIR;
        build_pkg_data_dir = Build.PKGDATADIR;
        build_release_name = Build.RELEASE_NAME;
        build_version = Build.VERSION;
        build_version_info = Build.VERSION_INFO;

        program_name = PROGRAM_NAME;
        exec_name = "envelope";

        app_copyright = "2014";
        application_id = "org.envelope.envelope";
        app_icon = "multimedia-audio-player";
        app_launcher = "envelope.desktop";
        app_years = "2014";

        main_url = "https://nlaplante.github.io/envelope";
        bug_url = "https://github.com/nlaplante/envelope/issues";
        help_url = "https://github.com/nlaplante/envelope/wiki";
        translate_url = "https://github.com/nlaplante/envelope";

        about_authors = {"Nicolas Laplante <nicolas.laplante@gmail.com>"};
        about_comments = "";
        about_license_type = Gtk.License.GPL_3_0;

        application_instance = this;
    }

    public static new unowned Envelope.App get_default () {
        if (application_instance == null) {
            application_instance = new Envelope.App ();
        }

        return application_instance;
    }

    public static void toast (string message) {
        get_default ().main_window.show_notification (message);
    }

    public MainWindow main_window { get; private set; }

    protected override void activate () {

        Granite.Services.Logger.initialize (PROGRAM_NAME);
        Granite.Services.Logger.DisplayLevel = DEBUG ? Granite.Services.LogLevel.DEBUG : Granite.Services.LogLevel.INFO;

        Granite.Services.Paths.initialize (Build.PROGRAM_NAME, Build.PKGDATADIR);

        info ("Report any issues/bugs you might find to %s".printf (bug_url));

        if (main_window == null) {
            main_window = new MainWindow ();
            main_window.set_application (this);
        }

        main_window.show ();
    }

    public string get_id () {
        return application_id;
    }

    public string get_name () {
        return PROGRAM_NAME;
    }
}

public static int main (string[] args) {
    var app = new Envelope.App ();
    return app.run (args);
}
