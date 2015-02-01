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

namespace Envelope.Widget {

    public class CellRendererPopoverContainer : AbstractPopoverCellRenderer {

        public CellRendererUpdatable? content { get; set; }

        public CellRendererPopoverContainer (Gtk.Widget relative_to) {
            base (relative_to);
        }

        public override unowned Gtk.CellEditable start_editing (Gdk.Event event,
                                                                Gtk.Widget widget,
                                                                string path,
                                                                Gdk.Rectangle background_area,
                                                                Gdk.Rectangle cell_area,
                                                                Gtk.CellRendererState flags) {

            unowned Gtk.CellEditable return_value = base.start_editing (event, widget, path, background_area, cell_area, flags);

            if (content == null) {
                return return_value;
            }

            // remove widget if needed
            var childs = popover.get_children ();

            if (childs.length () != 0 && childs.first ().data != content) {
                CellRendererUpdatable old_content = childs.first ().data as CellRendererUpdatable;
                old_content.dismiss.disconnect (on_content_dismiss);
                popover.remove (old_content);
            }

            content.update ();

            // add widget
            if (popover.get_children ().length () == 0) {
                content.dismiss.connect (on_content_dismiss);
                popover.add (content);
            }

            popover.show ();

            return null;
        }

        private void on_content_dismiss () {
            popover.hide ();
        }

        protected override void build_ui () {
            // noop
        }

        protected override void connect_signals () {
            // noop
        }
    }
}
