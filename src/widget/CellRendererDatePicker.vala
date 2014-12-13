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

        public Gtk.Calendar calendar { get; private set; }
        public Granite.Widgets.PopOver popover { get; private set; }

        public CellRendererDatePicker () {
            Object ();
            build_ui ();
            connect_signals ();
        }

        public override unowned Gtk.CellEditable start_editing (Gdk.Event event,
                                            Gtk.Widget widget,
                                            string path,
                                            Gdk.Rectangle background_area,
                                            Gdk.Rectangle cell_area,
                                            Gtk.CellRendererState flags) {

            /*weak Gtk.CellEditable return_value = base.start_editing (event, hack, path, background_area, cell_area,
                Gtk.CellRendererState.SELECTED |
                Gtk.CellRendererState.INSENSITIVE |
                Gtk.CellRendererState.EXPANDABLE |
                Gtk.CellRendererState.EXPANDED);
                */

            double x;
            double y;
            int cell_x;
            int cell_y;

            event.get_coords (out x, out y);
            retrieve_cell_position (event, widget, out cell_x, out cell_y);

            int pos_x = cell_area.x + cell_x + 10;
            int pos_y = cell_area.y + cell_y + ((int) (cell_area.height * 2.5));

            debug ("cell area x,y: %d,%d".printf (cell_area.x, cell_area.y));

            popover.move_to_coords (pos_x, pos_y);
            //popover.map_event ((Gdk.EventAny) event);

            return null;
        }

        private void retrieve_cell_position (Gdk.Event event, Gtk.Widget widget, out int x, out int y) {
            int w_x, w_y;
            Gtk.Allocation allocation;

            widget.get_window ().get_origin (out w_x, out w_y);
            widget.get_allocation (out allocation);

            w_x += allocation.x;
            w_y += allocation.y;

            x = w_x;
            y = w_y;
        }

        private void build_ui () {
            calendar = new Gtk.Calendar ();
            popover = new Granite.Widgets.PopOver ();

            popover.set_parent_pop (Envelope.App.get_default ().main_window);
            popover.get_content_area ().add (calendar);

            calendar.show_all ();

            mode = Gtk.CellRendererMode.ACTIVATABLE;
        }

        private void connect_signals () {

            var that = this;

            calendar.day_selected.connect (() => {
                popover.hide ();

                uint day;
                uint month;
                uint year;

                calendar.get_date (out day, out month, out year);

                var dt = new DateTime.local ((int) year, (int) month, (int) day, 0, 0, 0);

                that.text = dt.format (Granite.DateTime.get_default_date_format (false, true, true));
            });
        }
    }
}
