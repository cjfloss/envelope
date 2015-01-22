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
using Envelope.Dialog;
using Envelope.Widget;
using Envelope.Service;
using Gee;

namespace Envelope.View {

    private static BudgetOverview budget_overview_instance = null;

    private static const string STYLE_CLASS_INFLOW = ".inflow { font-weight: 900; font-size: 18px; color: #4e9a06; }";
    private static const string STYLE_CLASS_OUTFLOW = ".outflow { font-weight: 900; font-size: 18px; color: #A62626; }";


    public class BudgetOverview : Gtk.Box {

        private static const string STYLESHEET_BUDGET_OVERVIEW = """
        EnvelopeViewBudgetOverview {
            background-color: @base_color;
        }

        EnvelopeViewBudgetOverview GtkLabel {
            color: @placeholder_text_color;
            font: open sans 11;
            text-shadow: none;
        }

        EnvelopeViewBudgetOverview .h1,
        EnvelopeViewBudgetOverview .h3 {
            color: alpha(@text_color, 0.4);
        }
        """;

        private Gtk.Label inflow_value_label;
        private Gtk.Label outflow_value_label;
        private Gtk.Label remaining_value_label;
        private Gtk.Grid charts_container;

        public static new unowned BudgetOverview get_default () {
            if (budget_overview_instance == null) {
                budget_overview_instance = new BudgetOverview ();
            }

            return budget_overview_instance;
        }

        public Budget budget { get; set; }

        private BudgetOverview () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            budget_overview_instance = this;

            build_ui ();
            connect_signals ();
        }

        private void build_ui () {

            homogeneous = false;

            Granite.Widgets.Utils.set_theming (this, STYLESHEET_BUDGET_OVERVIEW, null, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            build_summary_ui ();
            build_charts_ui ();

            budget_changed ();
        }

        private void build_summary_ui () {

            // Top spacer
            pack_start (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), true, true, 0);

            var budget_state = BudgetManager.get_default ().state;

            var summary_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
//            set_class (summary_container, Granite.StyleClass.CONTENT_VIEW);
            pack_start (summary_container);

            var summary_title = new Gtk.Label(_("Your budget right now:"));
            set_class (summary_title, Granite.StyleClass.H1_TEXT);
            //Granite.Widgets.Utils.set_theming (summary_title, STYLE_CLASS_OVERVIEW_TITLE, "overview-title", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            summary_container.pack_start (summary_title);

            // Show horitonzal box with this month's inflow and outflow
            var in_out_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            summary_container.pack_start (in_out_box);

            var inflow_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            in_out_box.pack_start (inflow_box);

            var inflow_label = new Gtk.Label (_("Inflow:"));
            set_class (inflow_label, Granite.StyleClass.H2_TEXT);
            //Granite.Widgets.Utils.set_theming (inflow_label, STYLE_CLASS_OVERVIEW, "overview", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            inflow_box.pack_start (inflow_label, false);

            inflow_value_label = new Gtk.Label (Envelope.Util.String.format_currency(budget_state.inflow));
            Granite.Widgets.Utils.set_theming (inflow_value_label, STYLE_CLASS_INFLOW, "inflow", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            inflow_box.pack_start (inflow_value_label, false);

            var outflow_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            in_out_box.pack_start (outflow_box);

            var outflow_label = new Gtk.Label (_("Outflow:"));
            set_class (outflow_label, Granite.StyleClass.H2_TEXT);
            //Granite.Widgets.Utils.set_theming (outflow_label, STYLE_CLASS_OVERVIEW, "overview", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            outflow_box.pack_start (outflow_label, false);

            outflow_value_label = new Gtk.Label (Envelope.Util.String.format_currency(budget_state.outflow));
            Granite.Widgets.Utils.set_theming (outflow_value_label, STYLE_CLASS_OUTFLOW, "outflow", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            outflow_box.pack_start (outflow_value_label, false);

            var remaining_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            in_out_box.pack_start (remaining_box);

            var remaining_label = new Gtk.Label (_("Remaining this month:"));
            set_class (remaining_label, Granite.StyleClass.H2_TEXT);
            //Granite.Widgets.Utils.set_theming (remaining_label, STYLE_CLASS_OVERVIEW, "overview", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            remaining_box.pack_start (remaining_label, false);

            remaining_value_label = new Gtk.Label (Envelope.Util.String.format_currency(budget_state.remaining));
            Granite.Widgets.Utils.set_theming (remaining_value_label, STYLE_CLASS_OUTFLOW, "outflow", Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            remaining_box.pack_start (remaining_value_label, false);
        }

        private void build_charts_ui () {

            charts_container = new Gtk.Grid ();
            charts_container.row_spacing = 10;
            charts_container.column_spacing = 10;
            charts_container.column_homogeneous = false;
            charts_container.border_width = 12;
            pack_start (charts_container, true);

            generate_operations_summary ();

            charts_container.show_all ();

        }

        private void generate_operations_summary () {

            debug ("generating operations summary");

            var budget_manager = BudgetManager.get_default ();

            try {
                var categories = budget_manager.get_categories ();

                charts_container.foreach ( (widget) => {
                    charts_container.remove (widget);
                });

                foreach (Category category in categories) {

                    double inflow;
                    double outflow;
                    var transactions = budget_manager.compute_current_category_operations (category, out inflow, out outflow);

                    if (!transactions.is_empty) {

                        var category_label = new Gtk.Label (category.name);
                        set_class (category_label, Granite.StyleClass.H2_TEXT);
                        category_label.xalign = 1.0f;

                        var category_summary_str = "";

                        bool inflow_set = false;
                        bool outflow_set = false;

                        if (inflow != 0) {
                            category_summary_str += "%s earned".printf (Envelope.Util.String.format_currency (inflow));
                            inflow_set = true;
                        }

                        if (outflow != 0) {
                            if (inflow_set) {
                                category_summary_str += ", %s spent".printf (Envelope.Util.String.format_currency (outflow));
                            }
                            else {
                                category_summary_str += "%s spent".printf (Envelope.Util.String.format_currency (outflow));
                            }

                            outflow_set = true;
                        }

                        category_summary_str += " in %d operation%s".printf (transactions.size, transactions.size > 1 ? "s" : "");


                        var category_summary = new Gtk.Label (category_summary_str);
                        set_class (category_summary, Granite.StyleClass.H3_TEXT);
                        category_summary.xalign = 0.0f;

                        charts_container.attach_next_to (category_label, null, Gtk.PositionType.BOTTOM, 1, 1);
                        charts_container.attach_next_to (category_summary, category_label, Gtk.PositionType.RIGHT, 1, 1);
                    }
                }

                charts_container.show_all ();
            }
            catch (ServiceError err) {
                error ("could not build budget overview (%s)", err.message);
            }
        }

        private void connect_signals () {
            BudgetManager.get_default ().budget_changed.connect (budget_changed);
        }

        private void budget_changed () {
            var budget_state = BudgetManager.get_default ().state;

            inflow_value_label.label = Envelope.Util.String.format_currency (budget_state.inflow);
            outflow_value_label.label = Envelope.Util.String.format_currency (budget_state.outflow);
            remaining_value_label.label = Envelope.Util.String.format_currency (Math.fabs (budget_state.inflow) - Math.fabs (budget_state.outflow));

            generate_operations_summary ();
        }

        private static void set_class (Gtk.Widget widget, string style_class) {
            var style_ctx = widget.get_style_context ();
            style_ctx.add_class (style_class);
        }
    }
}
