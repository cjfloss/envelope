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

    /**
     * This is the base class for all cell renderers showing content in a
     * Gtk.Popover.
     */
    public abstract class AbstractPopoverCellRenderer : CellRendererTextCompletion {

        public Gtk.Widget relative_to { get; set; }
        public Gtk.Popover popover { get; private set; }

        public signal void dismissed ();

        protected string? current_path;

        protected abstract void build_ui ();
        protected abstract void connect_signals ();

        protected AbstractPopoverCellRenderer (Gtk.Widget relative_to) {
            base ();
            this.relative_to = relative_to;

            build_real_ui ();
            connect_real_signals ();
        }

        public override unowned Gtk.CellEditable start_editing ( Gdk.Event event,
                                        Gtk.Widget widget,
                                        string path,
                                        Gdk.Rectangle background_area,
                                        Gdk.Rectangle cell_area,
                                        Gtk.CellRendererState flags) {

            unowned Gtk.CellEditable return_value = base.start_editing (event, widget, path, background_area, cell_area, flags);

            current_path = path;

            Cairo.RectangleInt pos;
            bool set_top = determine_position (cell_area, out pos);

            popover.pointing_to = pos;
            popover.relative_to = widget;
            popover.set_position (set_top ? Gtk.PositionType.TOP : Gtk.PositionType.BOTTOM);

            return return_value;
        }

        private void build_real_ui () {
            mode = Gtk.CellRendererMode.EDITABLE;
            editable = true;
            editable_set = true;

            popover = new Gtk.Popover (relative_to);
            popover.modal = true;
            popover.border_width = 12;
            popover.set_position (Gtk.PositionType.BOTTOM);

            build_ui ();
        }

        private void connect_real_signals () {

            // close popover when treeview's model changes
            Gtk.TreeView treeview = relative_to as Gtk.TreeView;

            treeview.model.row_changed.connect ( () => {
                real_dismiss ();
            });

            treeview.model.row_deleted.connect ( () => {
                real_dismiss ();
            });

            treeview.model.row_has_child_toggled.connect ( () => {
                real_dismiss ();
            });

            treeview.model.row_inserted.connect ( () => {
                real_dismiss ();
            });

            treeview.model.rows_reordered.connect ( () => {
                real_dismiss ();
            });

            popover.closed.connect ( () => {
                dismissed ();
            });

            connect_signals ();
        }

        private void real_dismiss () {
            popover.hide ();
        }

        private bool determine_position (Gdk.Rectangle area, out Cairo.RectangleInt position) {
            position = Cairo.RectangleInt ();

            position.width = area.width;
            position.height = area.height;
            position.y = area.y/* + area.height + 2*/;
            position.x = area.x;

            return false;
        }
    }
}
