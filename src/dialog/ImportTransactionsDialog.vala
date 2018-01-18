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

using Envelope.Service;
using Envelope.View;

namespace Envelope.Dialog {
    public class ImportTransactionsDialog : Gtk.FileChooserDialog {
        public ImportTransactionsDialog () {
            Object (title: _("Import transactions from file"),
                parent: Envelope.App.get_default ().main_window,
                action: Gtk.FileChooserAction.OPEN);

            build_ui ();
        }

        private void build_ui () {
            add_button ("_Cancel", Gtk.ResponseType.CANCEL);
            add_button ("_Open", Gtk.ResponseType.ACCEPT);

            debug ("pointing file chooser to path: %s".printf (Granite.Services.Paths.home_folder.get_path ()));

            select_multiple = false;
            create_folders = false;

            try {
                set_current_folder_file (Granite.Services.Paths.home_folder);
            } catch (Error err) {
                warning ("could not point chooser to home folder (%s)".printf (err.message));
            }

            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.qif");

            set_filter (filter);
        }

        // call this instead of run ()
        public void execute () {
            var response = run ();

            switch (response) {
                case Gtk.ResponseType.ACCEPT:
                case Gtk.ResponseType.OK:
                    close ();

                    try {
                        var account_ref = Sidebar.get_default ().selected_account;

                        int size = AccountManager.get_default ().import_transactions_from_file (ref account_ref, get_file ());

                        Envelope.App.toast (_("%d transactions imported in account %s").printf(size, account_ref.number));

                        // refresh search autocompletion
                        MerchantStore.get_default ().reload ();
                    } catch (ServiceError err) {
                        error (err.message);
                    } catch (ImporterError err) {
                        error (err.message);
                    }
                    break;
                case Gtk.ResponseType.CANCEL:
                case Gtk.ResponseType.CLOSE:
                    close ();
                    break;
                default:
                    assert_not_reached ();
            }
        }
    }
}
