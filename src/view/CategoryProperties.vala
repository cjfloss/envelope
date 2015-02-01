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

using Envelope.Widget;
using Envelope.Service;

namespace Envelope.View {

    public class CategoryProperties : CellRendererUpdatable {

        public MonthlyCategory category { get; set; }
        public double inflow { get; set; }
        public double outflow { get; set; }

        private Gtk.Entry category_name_entry;
        private Gtk.Entry budgeted_amount_entry;
        private Gtk.Label date_label;
        private Gtk.Label inflow_label;
        private Gtk.Label inflow_label_label;
        private Gtk.Label outflow_label;
        private Gtk.Label outflow_label_label;
        private Gtk.Label remaining_label;
        private Gtk.Label remaining_label_label;
        private Gtk.Label empty_label;
        private Gtk.Button ok_button;
        private Gtk.Button cancel_button;

        private BudgetManager bm = BudgetManager.get_default ();

        public CategoryProperties () {
            Object ();
            build_ui ();
            connect_signals ();
        }

        public override void update () {
            category_name_entry.text = category.name;
            budgeted_amount_entry.text = Envelope.Util.String.format_currency (category.amount_budgeted);

            inflow_label.label = Envelope.Util.String.format_currency (inflow);
            inflow_label.visible = inflow > 0d;
            inflow_label_label.visible = inflow_label.visible;

            outflow_label.label = Envelope.Util.String.format_currency (outflow);
            outflow_label.visible = outflow > 0d;
            outflow_label_label.visible = outflow_label.visible;

            double remaining = category.amount_budgeted - outflow + inflow;
            remaining_label.label = Envelope.Util.String.format_currency (remaining);
            remaining_label.visible = category.amount_budgeted != 0d;
            remaining_label_label.visible = remaining_label.visible;

            empty_label.visible = outflow == 0d && inflow == 0d;
        }

        private void build_ui () {

            column_spacing = 10;
            row_spacing = 10;
            column_homogeneous = true;

            // category name text entry
            category_name_entry = new Gtk.Entry ();
            attach_next_to (category_name_entry, null, Gtk.PositionType.TOP, 2, 1);

            date_label = new Gtk.Label ("");
            //Granite.Widgets.Utils.apply_text_style_to_label (Granite.TextStyle.H2, date_label);
            //grid.attach_next_to (date_label, null, Gtk.PositionType.BOTTOM, 2, 1);

            // budgeted amount
            var budgeted_amount_label = new Gtk.Label (_("Budget"));
            budgeted_amount_label.xalign = 1.0f;
            attach_next_to (budgeted_amount_label, null, Gtk.PositionType.BOTTOM, 1, 1);

            budgeted_amount_entry = new Gtk.Entry ();
            budgeted_amount_entry.width_chars = 10;
            budgeted_amount_entry.max_width_chars = 10;
            attach_next_to (budgeted_amount_entry, budgeted_amount_label, Gtk.PositionType.RIGHT, 1, 1);

            // outflow
            outflow_label_label = new Gtk.Label (_("Outflow"));
            outflow_label_label.xalign = 1.0f;
            attach_next_to (outflow_label_label, null, Gtk.PositionType.BOTTOM, 1, 1);

            outflow_label = new Gtk.Label ("");
            outflow_label.xalign = 0.0f;
            attach_next_to (outflow_label, outflow_label_label, Gtk.PositionType.RIGHT, 1, 1);

            // inflow
            inflow_label_label = new Gtk.Label (_("Inflow"));
            inflow_label_label.xalign = 1.0f;
            attach_next_to (inflow_label_label, null, Gtk.PositionType.BOTTOM, 1, 1);

            inflow_label = new Gtk.Label ("");
            inflow_label.xalign = 0.0f;
            attach_next_to (inflow_label, inflow_label_label, Gtk.PositionType.RIGHT, 1, 1);

            // remaining
            remaining_label_label = new Gtk.Label (_("Remaining"));
            remaining_label_label.xalign = 1.0f;
            attach_next_to (remaining_label_label, null, Gtk.PositionType.BOTTOM, 1, 1);

            remaining_label = new Gtk.Label ("");
            remaining_label.xalign = 0.0f;
            attach_next_to (remaining_label, remaining_label_label, Gtk.PositionType.RIGHT, 1, 1);

            // empty label
            empty_label = new Gtk.Label (_("No transactions recorded for this cateogry yet"));
            attach_next_to (empty_label, null, Gtk.PositionType.BOTTOM, 2, 1);

            // Cancel button
            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            attach_next_to (cancel_button, null, Gtk.PositionType.BOTTOM, 1, 1);

            // OK button
            ok_button = new Gtk.Button.with_label (_("Apply"));
            ok_button.get_style_context ().add_class("suggested-action");
            attach_next_to (ok_button, cancel_button, Gtk.PositionType.RIGHT, 1, 1);

            show_all ();
        }

        private void connect_signals () {
            cancel_button.clicked.connect (cancel_clicked);
            ok_button.clicked.connect (ok_clicked);
        }

        private void cancel_clicked () {
            dismiss ();
        }

        private void ok_clicked () {

            category.name = category_name_entry.text.strip ();
            category.amount_budgeted = Envelope.Util.String.parse_currency (budgeted_amount_entry.text);

            try {
                bm.set_current_budgeted_amount (category);
                bm.update_category (category);
            }
            catch (ServiceError err) {
                error ("could not update category (%s)", err.message);
            }

            dismiss ();
        }
    }
}
