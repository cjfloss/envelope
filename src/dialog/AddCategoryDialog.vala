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
using Envelope.Util.String;

namespace Envelope.Dialog {
    public class AddCategoryDialog : Gtk.Dialog {
        private Gtk.Entry name_entry;
        private Gtk.Entry amount_entry;
        private Gtk.Button create_button;
        private Gtk.Button cancel_button;

        public AddCategoryDialog (Gtk.Window parent) {
            Object (transient_for: parent);
        }

        construct {
            deletable = false;
            modal = true;
            resizable= false;
            width_request = 300;
            window_position = Gtk.WindowPosition.CENTER_ON_PARENT;

            var grid = new Gtk.Grid ();
            get_content_area ().add (grid);

            grid.margin_start = grid.margin_end = 12;
            grid.row_spacing = grid.column_spacing = 12;
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.valign = Gtk.Align.CENTER;
            grid.vexpand = true;

            var name_label = new Gtk.Label (_("Name:"));
            name_label.xalign = 1.0f;
            grid.attach (name_label, 1, 1, 1, 1);

            name_entry = new Gtk.Entry ();
            name_entry.placeholder_text = _("Category name");
            name_entry.expand = true;
            name_entry.key_release_event.connect (() => {
                if (name_entry.get_text () == "") {
                    create_button.sensitive = false;
                } else {
                    create_button.sensitive = true;
                    amount_entry.placeholder_text = _("Monthly Budget for %s")
                        .printf(name_entry.get_text ());
                }
            });

            grid.attach (name_entry, 2, 1, 2, 1);

            var amount_label = new Gtk.Label (_("Budget:"));
            amount_label.xalign = 1.0f;
            grid.attach (amount_label, 1, 2, 1, 1);

            amount_entry = new Gtk.Entry ();
            amount_entry.placeholder_text = _("Monthly Budget for");
            grid.attach (amount_entry, 2, 2, 2, 1);

            create_button = new Gtk.Button.with_label (_("Create Category"));
            create_button.sensitive = false;
            create_button.get_style_context ()
                                .add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            create_button.clicked.connect (() => {
                this.create_category ();
                this.destroy ();
            });

            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.clicked.connect (() => {
                this.destroy ();
            });

            var action_area = (Gtk.Container) get_action_area ();
            action_area.margin = 6;
            action_area.margin_top = 14;
            action_area.add (cancel_button);
            action_area.add (create_button);
            action_area.show_all ();

            grid.show_all ();
        }

        private void create_category () {
            try {
                BudgetManager.get_default ()
                    .create_category (name_entry.text.strip (),
                                    parse_currency (amount_entry.text.strip ())
                                    );
            } catch (ParseError err) {
                error ("could not create category %s (%s)", name_entry.text, err.message);
            } catch (ServiceError err) {
                error ("could not create category %s (%s)", name_entry.text, err.message);
            }
        }
    }
}
