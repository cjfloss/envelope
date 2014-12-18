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

namespace Envelope.Service.Settings {

    private static SavedState saved_state_instance = null;

    public class SavedState : /*Granite.Services.Settings*/ Object {

        public Gdk.WindowState? window_state { get; set; }
        public Gtk.WindowPosition? window_position { get; set; }

        public int? window_width { get; set; }
        public int? window_height { get; set; }

        public int sidebar_width { get; set; }

        public string search_term { get; set; }

        public int selected_account_id { get; set; }
        public int selected_category_id { get; set; }

        public bool this_month_selected { get; set; }
        public bool last_month_selected { get; set; }
        public bool future_selected { get; set; }
        public bool manual_date_selected { get; set; }

        public DateTime from_date { get; set; }
        public DateTime to_date { get; set; }

        public static SavedState get_default () {
            if (saved_state_instance == null) {
                saved_state_instance = new SavedState ();
            }

            return saved_state_instance;
        }

        private SavedState () {
            Object ();
            //base ("org.envelope.saved-state");
        }
    }
}
