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

namespace Envelope.Widget {

    public class CellRendererDatePicker : AbstractPopoverCellRenderer {

        private static string date_format = "%x";

        public Gtk.Calendar calendar { get; private set; }
        public bool date_selected { get; private set; }

        public CellRendererDatePicker (Gtk.Widget relative_to) {
            base (relative_to);
        }

        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                            Gtk.Widget widget,
                                            string path,
                                            Gdk.Rectangle background_area,
                                            Gdk.Rectangle cell_area,
                                            Gtk.CellRendererState flags) {

            base.start_editing (event, widget, path, background_area, cell_area, flags);
            popover.show ();

            return null;
        }

        protected override void build_ui () {

            calendar = new Gtk.Calendar ();
            popover.add (calendar);

            calendar.show_all ();
        }

        protected override void connect_signals () {
            calendar.day_selected.connect (select_date);
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
