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

namespace Envelope {

    public class CellRendererDatePicker : Gtk.CellRendererText {

        private static string date_format = Granite.DateTime.get_default_date_format (false, true, true);

        public Gtk.Calendar calendar { get; private set; }
        public Gtk.Popover popover { get; private set; }
        public bool date_selected { get; private set; }

        private Gtk.Widget relative_to { get; set; }
        private string? current_path;

        public CellRendererDatePicker (Gtk.Widget relative_to) {
            Object ();

            this.relative_to = relative_to;

            build_ui ();
            connect_signals ();
        }

        public override unowned Gtk.CellEditable start_editing (Gdk.Event event,
                                            Gtk.Widget widget,
                                            string path,
                                            Gdk.Rectangle background_area,
                                            Gdk.Rectangle cell_area,
                                            Gtk.CellRendererState flags) {

            weak Gtk.CellEditable ret = base.start_editing (event, widget, path, background_area, cell_area, flags);

            current_path = path;

            Cairo.RectangleInt pos;
            determine_position (cell_area, out pos);

            popover.pointing_to = pos;
            popover.relative_to = widget;
            popover.show ();

            return ret;
        }

        private void determine_position (Gdk.Rectangle area, out Cairo.RectangleInt position) {
            position = Cairo.RectangleInt ();

            position.width = area.width;
            position.height = area.height;
            position.y = area.y + area.height + 2;
            position.x = area.x;
        }

        private void build_ui () {
            calendar = new Gtk.Calendar ();

            popover = new Gtk.Popover (relative_to);
            popover.modal = false;
            popover.border_width = 10;
            popover.set_position (Gtk.PositionType.BOTTOM);
            popover.add (calendar);

            calendar.show_all ();
        }

        private void connect_signals () {
            calendar.day_selected_double_click.connect (select_date);
        }

        private void select_date () {

            popover.hide ();

            date_selected = true;

            var dt = new DateTime.local (calendar.year, calendar.month + 1, calendar.day, 0, 0, 0);

            edited (current_path, dt.format (date_format));

            date_selected = false;
            current_path = null;
        }
    }
}
