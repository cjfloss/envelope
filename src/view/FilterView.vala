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

namespace Envelope.View {

    public class FilterView : Gtk.Box {

        private static FilterView filter_view_instance = null;

        public static new FilterView get_default () {
            if (filter_view_instance == null) {
                filter_view_instance = new FilterView ();
            }

            return filter_view_instance;
        }

        public signal void date_filter_changed ();

        public DateTime from { get; private set; }
        public DateTime to { get; private set; }

        public enum FilterType {
            THIS_MONTH,
            LAST_MONTH,
            FUTURE,
            MANUAL
        }

        public FilterType                  filter_type      { get; set; }

        public Gtk.RadioButton             btn_this_month   { get; private set; }
        public Gtk.RadioButton             btn_last_month   { get; private set; }
        public Gtk.RadioButton             btn_future       { get; private set; }
        public Gtk.RadioButton             btn_manual       { get; private set; }
        public Granite.Widgets.DatePicker  from_date        { get; private set; }
        public Granite.Widgets.DatePicker  to_date          { get; private set; }

        private FilterView () {
            Object (orientation: Gtk.Orientation.VERTICAL);

            filter_type = FilterType.THIS_MONTH;

            DateTime d_from, d_to;

            compute_dates (out d_from, out d_to);
            from = d_from;
            to = d_to;

            build_ui ();
            connect_signals ();
            
            filter_view_instance = this;
        }

        private void build_ui () {

            debug ("build filter ui");

            set_spacing (5);

            var inner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            pack_start (inner_box);

            var title_image = new Gtk.Image.from_icon_name ("office-calendar", Gtk.IconSize.LARGE_TOOLBAR);
            inner_box.pack_start (title_image, false, false);

            // this month
            btn_this_month = new Gtk.RadioButton (null);
            btn_this_month.label = _("This month");
            inner_box.pack_start (btn_this_month, false, false);

            // last month
            btn_last_month = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Last month"));
            inner_box.pack_start (btn_last_month, false, false);

            // future
            btn_future = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Future"));
            inner_box.pack_start (btn_future, false, false);

            // manual dates
            btn_manual = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Pick dates:"));
            inner_box.pack_start (btn_manual, false, false);

            from_date = new Granite.Widgets.DatePicker ();
            from_date.sensitive = false;
            from_date.date = new DateTime.now_local ().add_months (-1);
            inner_box.pack_start (from_date, false, false);

            to_date = new Granite.Widgets.DatePicker ();
            to_date.sensitive = false;
            to_date.date = new DateTime.now_local ();
            inner_box.pack_start (to_date, false, false);
        }

        private void connect_signals () {

            debug ("connect filter view signals");

            notify["filter-type"].connect ( (s, p) => {
                switch (filter_type) {
                    case FilterType.THIS_MONTH:
                        btn_this_month.active = true;
                        break;
                        
                    case FilterType.LAST_MONTH:
                        btn_last_month.active = true;
                        break;
                    
                    case FilterType.FUTURE:
                        btn_future.active = true;
                        break ;
                        
                    case FilterType.MANUAL:
                        btn_manual.active = true;
                        break;
                        
                    default:
                        assert_not_reached ();
                }
            });

            btn_last_month.toggled.connect ( () => {
                if (btn_last_month.get_active ()) {
                    filter_type = FilterType.LAST_MONTH;
                    fire_date_filter_changed_signal ();
                }
            });

            btn_this_month.toggled.connect ( () => {
                if (btn_this_month.get_active ()) {
                    filter_type = FilterType.THIS_MONTH;
                    fire_date_filter_changed_signal ();
                }
            });

            btn_future.toggled.connect ( () => {
                if (btn_future.get_active ()) {
                    filter_type = FilterType.FUTURE;
                    fire_date_filter_changed_signal ();
                }
            });

            btn_manual.toggled.connect ( () => {
                if (btn_manual.get_active ()) {

                    filter_type = FilterType.MANUAL;

                    from_date.sensitive = true;
                    to_date.sensitive = true;

                    if (from_date.date != null && to_date.date != null) {
                        fire_date_filter_changed_signal ();
                    }
                }
                else {
                    from_date.sensitive = false;
                    to_date.sensitive = false;
                }
            });

            from_date.notify["date"].connect ( () => {
                if (btn_manual.get_active () && from_date.date != null && to_date.date != null) {
                    fire_date_filter_changed_signal ();
                }
            });

            to_date.notify["date"].connect ( () => {
                if (btn_manual.get_active () && from_date.date != null && to_date.date != null) {
                    fire_date_filter_changed_signal ();
                }
            });
        }

        private void compute_dates (out DateTime? from, out DateTime? to) {

            int month, year;
            Envelope.Util.Date.get_year_month (out year, out month);

            switch (filter_type) {
                case FilterType.THIS_MONTH:

                    Envelope.Util.Date.get_month_boundaries (year, month, out from, out to);
                    break;

                case FilterType.LAST_MONTH:

                    int last_month, last_year;
                    Envelope.Util.Date.months_ago (1, out last_year, out last_month);

                    Envelope.Util.Date.get_month_boundaries (last_year, last_month, out from, out to);
                    break;

                case FilterType.FUTURE:

                    Envelope.Util.Date.tomorrow (out from);
                    to = null;

                    break;

                case FilterType.MANUAL:

                    from = from_date.date;
                    to = to_date.date;

                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void fire_date_filter_changed_signal () {

            DateTime d_from, d_to;

            compute_dates (out d_from, out d_to);

            from = d_from;
            to = d_to;

            date_filter_changed ();
        }

    }
}
