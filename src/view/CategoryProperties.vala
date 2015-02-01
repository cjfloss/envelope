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

        private static const int ENTRY_WIDTH = 15;

        public MonthlyCategory category { get; set; }
        public double inflow { get; set; }
        public double outflow { get; set; }

        private Gtk.Entry category_name_entry;
        private Gtk.Entry budgeted_amount_entry;
        private Gtk.Label inflow_label;
        private Gtk.Label inflow_label_label;
        private Gtk.Label outflow_label;
        private Gtk.Label outflow_label_label;
        private Gtk.Label remaining_label;
        private Gtk.Label remaining_label_label;
        private Gtk.Label available_label;
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
            budgeted_amount_entry.text = category.amount_budgeted != 0d ?
                Envelope.Util.String.format_currency (category.amount_budgeted) : "";

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

            available_label.label = "Max. %s".printf (Envelope.Util.String.format_currency (BudgetManager.get_default ().state.budget_available));
        }

        private void build_ui () {

            column_spacing = 10;
            row_spacing = 10;
            //column_homogeneous = true;

            // title
            var title_label = new Gtk.Label (_("Edit category"));
            Granite.Widgets.Utils.apply_text_style_to_label (Granite.TextStyle.H3, title_label);
            attach_next_to (title_label, null, Gtk.PositionType.TOP, 3, 1);

            // category name text entry
            var category_name_label = new Gtk.Label (_("Name"));
            category_name_label.xalign = 1.0f;
            attach_next_to (category_name_label, title_label, Gtk.PositionType.BOTTOM, 1, 1);

            category_name_entry = new Gtk.Entry ();
            category_name_entry.width_chars = ENTRY_WIDTH;
            category_name_entry.max_width_chars = ENTRY_WIDTH;
            attach_next_to (category_name_entry, category_name_label, Gtk.PositionType.RIGHT, 2, 1);

            // budgeted amount
            var budgeted_amount_label = new Gtk.Label (_("Budget"));
            budgeted_amount_label.xalign = 1.0f;
            attach_next_to (budgeted_amount_label, null, Gtk.PositionType.BOTTOM, 1, 1);

            budgeted_amount_entry = new Gtk.Entry ();
            budgeted_amount_entry.width_chars = ENTRY_WIDTH;
            budgeted_amount_entry.max_width_chars = ENTRY_WIDTH;
            budgeted_amount_entry.placeholder_text = _("Monthly budget");
            attach_next_to (budgeted_amount_entry, budgeted_amount_label, Gtk.PositionType.RIGHT, 1, 1);

            available_label = new Gtk.Label ("");
            available_label.xalign = 0.0f;
            attach_next_to (available_label, budgeted_amount_entry, Gtk.PositionType.RIGHT, 1, 1);

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

            // button box
            var box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            box.set_layout (Gtk.ButtonBoxStyle.END);
            box.set_spacing (5);
            attach_next_to (box, null, Gtk.PositionType.BOTTOM, 3, 1);

            // Cancel button
            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            box.add (cancel_button);

            // OK button
            ok_button = new Gtk.Button.with_label (_("Apply"));
            ok_button.get_style_context ().add_class("suggested-action");
            box.add (ok_button);

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
