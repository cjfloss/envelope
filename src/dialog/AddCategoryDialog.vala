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

    public class AddCategoryDialog : Gtk.Dialog {

        private Gtk.Entry name_entry;
        private Gtk.Entry amount_entry;
        private Gtk.Button ok_button;

        public AddCategoryDialog () {
            Object ();

            build_ui ();
            connect_signals ();
        }

        private void build_ui () {

            title = _("Add a category");
            border_width = 20;

            // Add buttons
            add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
            ok_button = add_button (_("Ok"), Gtk.ResponseType.APPLY) as Gtk.Button;
            ok_button.get_style_context ().add_class("suggested-action");;
            ok_button.sensitive = false;

            Gtk.Box content = get_content_area () as Gtk.Box;
            content.spacing = 20;

            var grid = new Gtk.Grid ();
            grid.row_spacing = 10;
            grid.column_spacing = 20;
            content.add (grid);

            grid.show_all ();

            var name_label = new Gtk.Label (_("Name:"));
            name_label.xalign = 1.0f;
            grid.attach_next_to (name_label, null, Gtk.PositionType.LEFT, 1, 1);

            name_entry = new Gtk.Entry ();
            name_entry.placeholder_text = _("Category name");
            grid.attach_next_to (name_entry, name_label, Gtk.PositionType.RIGHT, 1, 1);

            var amount_label = new Gtk.Label (_("Budgeted amount:"));
            amount_label.xalign = 1.0f;
            grid.attach_next_to (amount_label, name_label, Gtk.PositionType.BOTTOM, 1, 1);

            amount_entry = new Gtk.Entry ();
            amount_entry.placeholder_text = _("Eg: 200");
            grid.attach_next_to (amount_entry, amount_label, Gtk.PositionType.RIGHT, 1, 1);

        }

        private void connect_signals () {
            response.connect (on_response);
            
            name_entry.changed.connect ( () => {
                ok_button.sensitive = name_entry.text.length > 0;
            });
        }

        private void on_response (Gtk.Dialog source, int response_id) {
            switch (response_id) {
                case Gtk.ResponseType.APPLY:
                    create_category ();
                    destroy ();
                    break;

                case Gtk.ResponseType.CLOSE:
                    destroy ();
                    break;
            }
        }

        private void create_category () {
            try {
                BudgetManager.get_default ().create_category (name_entry.text.strip ());
            }
            catch (ServiceError err) {
                error ("could not create category %s (%s)", name_entry.text, err.message);
            }
        }
    }
}
