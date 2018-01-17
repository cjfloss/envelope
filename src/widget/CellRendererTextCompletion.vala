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

    public class CellRendererTextCompletion : Gtk.CellRendererText {

        public Gtk.ListStore store { get; set; }
        public int text_column { get; set; }

        private string path;
        private Gtk.Entry text_entry;

        public CellRendererTextCompletion () {
            Object ();
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            text_entry = new Gtk.Entry ();
        }

        private void connect_signals () {
            text_entry.editing_done.connect (done_editing);
        }

        private void done_editing () {
            edited (path, text_entry.text);
        }

        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                                                Gtk.Widget widget,
                                                                string path,
                                                                Gdk.Rectangle background_area,
                                                                Gdk.Rectangle cell_area,
                                                                Gtk.CellRendererState flags) {

            assert (editable);

            // create new completion every time, since the backing store might
            // have changed since last time
            var entry_completion = new Gtk.EntryCompletion ();
            entry_completion.set_model (store);
            entry_completion.set_text_column (text_column);

            text_entry.completion = entry_completion;

            this.path = path;
            text_entry.show ();
            text_entry.grab_focus ();

            return text_entry;
        }
    }
}
