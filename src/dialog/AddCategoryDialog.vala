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
    public class AddCategoryDialog : AbstractOkCancelDialog {
        private Gtk.Entry name_entry;
        private Gtk.Entry amount_entry;

        public AddCategoryDialog () {
            base ();
        }

        protected override Gtk.Widget build_content () {
            ok_button.sensitive = false;

            var grid = new Gtk.Grid ();
            grid.row_spacing = 10;
            grid.column_spacing = 20;

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

            return grid;
        }

        protected override void connect_signals () {
            base.connect_signals ();
            name_entry.changed.connect (validate_input);
            amount_entry.changed.connect (validate_input);
        }

        private void validate_input () {
            ok_button.sensitive = name_entry.text.length > 0;
        }

        protected override void apply_cb () {
            try {
                BudgetManager.get_default ()
                    .create_category (name_entry.text.strip (), parse_currency (amount_entry.text.strip ()));
            } catch (ParseError err) {
                error ("could not create category %s (%s)", name_entry.text, err.message);
            } catch (ServiceError err) {
                error ("could not create category %s (%s)", name_entry.text, err.message);
            }
        }

        protected override void cancel_cb () { }
    }
}
