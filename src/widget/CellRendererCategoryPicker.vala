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

    public class CellRendererCategoryPicker : AbstractPopoverCellRenderer {

        public string merchant_name { get; set; }
        public string category_name { get; set; }
        public bool apply_to_all { get; private set; }

        private Gtk.Entry category_entry;
        private Gtk.CheckButton check_button;
        private Gtk.Button ok_button;
        private Gtk.Button cancel_button;

        private Gtk.EntryCompletion completion;

        public CellRendererCategoryPicker (Gtk.Widget relative_to) {
            base (relative_to);
        }

        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                       Gtk.Widget widget,
                                       string path,
                                       Gdk.Rectangle background_area,
                                       Gdk.Rectangle cell_area,
                                       Gtk.CellRendererState flags) {

            base.start_editing (event, widget, path, background_area, cell_area, flags);

            check_button.label = _("Apply to all %s").printf (merchant_name);

            completion = new Gtk.EntryCompletion ();
            completion.set_model (store);
            completion.set_text_column (text_column);
            completion.inline_completion = true;
            completion.inline_selection = true;
            completion.minimum_key_length = 0;
            completion.popup_completion = true;
            completion.popup_single_match = true;

            category_entry.completion = completion;
            category_entry.text = category_name;

            category_entry.focus.connect ( () => {
                completion.complete ();
                return true;
            });

            popover.show ();
            category_entry.grab_focus ();

            return null;
        }

        protected override void build_ui () {

            var grid = new Gtk.Grid ();

            grid.column_spacing = 10;
            grid.row_spacing = 10;
            popover.add (grid);

            category_entry = new Gtk.Entry ();
            category_entry.placeholder_text = _("Category name");

            grid.attach_next_to (category_entry, null, Gtk.PositionType.BOTTOM, 2, 1);

            // apply to all
            check_button = new Gtk.CheckButton.with_label (_("Apply to all %s").printf (merchant_name));

            grid.attach_next_to (check_button, null, Gtk.PositionType.BOTTOM, 2, 1);

            // Cancel button
            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            grid.attach_next_to (cancel_button, null, Gtk.PositionType.BOTTOM, 1, 1);

            // OK button
            ok_button = new Gtk.Button.with_label (_("Set category"));
            ok_button.get_style_context ().add_class("suggested-action");
            grid.attach_next_to (ok_button, cancel_button, Gtk.PositionType.RIGHT, 1, 1);

            grid.show_all ();
        }

        protected override void connect_signals () {

            cancel_button.clicked.connect ( () => {
                check_button.active = false;
                popover.hide ();
            });

            ok_button.clicked.connect ( () => {
                edited (current_path, category_entry.text);
                check_button.active = false;
                popover.hide ();
            });

            check_button.toggled.connect ( () => {
                apply_to_all = check_button.active;
            });
        }
    }

}
