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

namespace Envelope.Dialog {
    public class AddAccountDialog : Gtk.Dialog {
        private Account.Type current_account_type = Account.Type.CHECKING;

        private Gtk.Entry number_entry;
        private Gtk.Entry desc_entry;
        private Gtk.Entry balance_entry;
        private Gtk.ComboBox type_choice;
        private Gtk.Button create_button;
        private Gtk.Button cancel_button;

        public AddAccountDialog (Gtk.Window parent) {
            Object (
                transient_for: parent,
                title: _("Add an Account"),
                deletable: false,
                modal: true,
                resizable: false,
                width_request: 300,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );
        }

        construct {
            var grid = new Gtk.Grid ();
            get_content_area ().add (grid);

            grid.margin_start = 12;
            grid.margin_end = 12;
            grid.margin_top = 20;
            grid.row_spacing = 12;
            grid.column_spacing = 12;

            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.valign = Gtk.Align.CENTER;
            grid.vexpand = true;

            var number_label = new Gtk.Label (_("Label:"));
            number_label.xalign = 1f;
            grid.attach (number_label, 0, 1, 1, 1);

            number_entry = new Gtk.Entry ();
            number_entry.placeholder_text = _("Eg.: account number");
            number_entry.expand = true;
            number_entry.key_release_event.connect (() => {
                number_entry.get_text () == ""
                ? create_button.sensitive = false
                : create_button.sensitive = true;
            });
            grid.attach (number_entry, 1, 1, 1, 1);

            var type_label = new Gtk.Label (_("Type:"));
            type_label.xalign = 1f;
            grid.attach (type_label, 0, 2, 1, 1);

            var type_list_store = new Gtk.ListStore (2, typeof (string), typeof (int));
            Gtk.TreeIter type_list_store_iter;

            type_list_store.append (out type_list_store_iter);
            type_list_store.set (type_list_store_iter, 0,
                                 _("Checking"), 1, Account.Type.CHECKING);
            type_list_store.append (out type_list_store_iter);
            type_list_store.set (type_list_store_iter, 0,
                                 _("Savings"), 1, Account.Type.SAVINGS);

            type_choice = new Gtk.ComboBox.with_model (type_list_store);
            type_choice.expand = true;
            grid.attach (type_choice, 1, 2, 1, 1);

            var type_renderer = new Gtk.CellRendererText ();
            type_choice.pack_start (type_renderer, true);
            type_choice.add_attribute (type_renderer, "text", 0);

            type_choice.active = 0;

            type_choice.changed.connect (() => {
                type_choice.get_active_iter (out type_list_store_iter);

                int account_type;
                type_list_store.@get (type_list_store_iter, 1, out account_type, -1);

                current_account_type = Account.Type.from_int (account_type);
            });

            var balance_label = new Gtk.Label (_("Balance:"));
            balance_label.xalign = 1f;
            grid.attach (balance_label, 0, 3, 1, 1);

            balance_entry = new Gtk.Entry ();
            balance_entry.expand = true;
            balance_entry.placeholder_text = Envelope.Util.String.format_currency (0d);
            grid.attach (balance_entry, 1, 3, 1, 1);

            var desc_label = new Gtk.Label (_("Description:"));
            desc_label.xalign = 1f;
            grid.attach (desc_label, 0, 4, 1, 1);

            desc_entry = new Gtk.Entry ();
            desc_entry.expand = true;
            desc_entry.placeholder_text = _("Optional");
            grid.attach (desc_entry, 1, 4, 1, 1);
            grid.show_all ();

            create_button = new Gtk.Button.with_label (_("Create Account"));
            cancel_button = new Gtk.Button.with_label (_("Cancel"));

            create_button.sensitive = false;
            create_button.get_style_context ()
                        .add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            cancel_button.clicked.connect (() => {
                this.destroy ();
            });

            create_button.clicked.connect (() => {
                this.create_account ();
                this.destroy ();
            });

            var action_area = (Gtk.Container) get_action_area ();
            action_area.margin = 6;
            action_area.margin_top = 14;
            action_area.add (cancel_button);
            action_area.add (create_button);
            action_area.show_all ();
        }

        [Version (deprecated = true, deprecated_since = "", replacement = "AccountManager.accout_created")]
        public signal void account_created (Account account);

        private void create_account () {
            try {
                var account = AccountManager.get_default ()
                              .create_account (number_entry.text,
                                               desc_entry.text,
                                               double.parse (balance_entry.text),
                                               current_account_type);

                // show notification
                Envelope.App.toast (_("Account %s has been created").printf (account.number));
            } catch (ServiceError err) {
                error ("error while creating account (%s)".printf (err.message));
            } catch (AccountError err) {
                error ("error while creating account (%s)".printf (err.message));
            }
        }
    }
}
