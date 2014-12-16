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

using Envelope.DB;

namespace Envelope.Dialog {

    public class AddAccountDialog : Gtk.Dialog {

        private Account.Type current_account_type = Account.Type.CHECKING;

        private Gtk.Entry number_entry;
        private Gtk.Entry desc_entry;
        private Gtk.Entry balance_entry;
        private Gtk.ComboBox type_choice;

        public AddAccountDialog () {
            build_ui ();
            connect_signals ();
        }

        public signal void account_created (Account account);

        private void create_account () {
            var account = new Account ();

            debug ("number_entry.text: %s".printf (number_entry.text));
            debug ("desc_entry.text: %s".printf (desc_entry.text));
            debug ("balance_entry.text: %s".printf (balance_entry.text));
            debug ("account_type: %s".printf (current_account_type.to_string ()));

            account.number = number_entry.text;
            account.description = desc_entry.text;
            account.balance = double.parse (balance_entry.text);
            account.account_type = current_account_type;

            try {
                DatabaseManager.get_default ().create_account (account);

                // show notification
                Envelope.App.toast (_("Account %s has been created").printf(account.number));

                account_created (account);
            }
            catch (SQLHeavy.Error err) {
                error ("error while creating account (%s)".printf (err.message));
            }
        }

        private void connect_signals () {
            response.connect (on_response);
        }

        private void on_response (Gtk.Dialog source, int response_id) {
            switch (response_id) {
                case Gtk.ResponseType.CLOSE:
                    destroy ();
                    break;

                case Gtk.ResponseType.APPLY:
                    create_account ();
                    break;
            }
        }

        private void build_ui () {

            title = "Add an account";
            border_width = 20;

            // Add buttons
            add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
            add_button (_("Ok"), Gtk.ResponseType.APPLY);

            Gtk.Box content = get_content_area () as Gtk.Box;
            content.spacing = 20;

            var grid = new Gtk.Grid ();
            grid.row_spacing = 10;
            grid.column_spacing = 20;
            content.add (grid);

            grid.show_all ();

            var number_label = new Gtk.Label ("Account number:");
            number_label.xalign = 1f;
            grid.attach(number_label, 0, 1, 1, 1);

            number_entry = new Gtk.Entry ();
            number_entry.placeholder_text = "ID or number";
            number_entry.expand = true;
            grid.attach(number_entry, 1, 1, 1, 1);

            var type_label = new Gtk.Label ("Type:");
            type_label.xalign = 1f;
            grid.attach (type_label, 0, 2, 1, 1);

            var type_list_store = new Gtk.ListStore (2, typeof (string), typeof (int));
            Gtk.TreeIter type_list_store_iter;

            type_list_store.append (out type_list_store_iter);
            type_list_store.set (type_list_store_iter, 0, _("Checking"), 1, Account.Type.CHECKING);
            type_list_store.append (out type_list_store_iter);
            type_list_store.set (type_list_store_iter, 0, _("Savings"), 1, Account.Type.SAVINGS);

            type_choice = new Gtk.ComboBox.with_model (type_list_store);
            type_choice.expand = true;
            grid.attach (type_choice, 1, 2, 1, 1);

            var type_renderer = new Gtk.CellRendererText ();
            type_choice.pack_start (type_renderer, true);
            type_choice.add_attribute (type_renderer, "text", 0);

            type_choice.active = 0;

            type_choice.changed.connect (() => {
                Value val;

                type_choice.get_active_iter (out type_list_store_iter);
                type_list_store.get_value (type_list_store_iter, 1, out val);

                current_account_type = (Account.Type) val;
                });

            var balance_label = new Gtk.Label (_("Current balance:"));
            balance_label.xalign = 1f;
            grid.attach (balance_label, 0, 3, 1, 1);

            balance_entry = new Gtk.Entry ();
            balance_entry.expand = true;
            balance_entry.placeholder_text = Envelope.Util.format_currency (0d);
            grid.attach (balance_entry, 1, 3, 1, 1);

            var desc_label = new Gtk.Label (_("Description:"));
            desc_label.xalign = 1f;
            grid.attach (desc_label, 0, 4, 1, 1);

            desc_entry = new Gtk.Entry ();
            desc_entry.expand = true;
            desc_entry.placeholder_text = _("Optional");
            grid.attach (desc_entry, 1, 4, 1, 1);
        }

    }
}
