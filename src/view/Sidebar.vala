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

    public class Sidebar : Gtk.ScrolledWindow {

        private static const int COLUMN_COUNT = 4;

        private enum Action {
            NONE,
            ADD_ACCOUNT
        }

        private enum Column {
            LABEL,
            ACCOUNT,
            ICON,
            ACTION
        }

        private static const string COLOR_SUBZERO = "red";
        private static const string COLOR_ZERO = "green";

        private Gtk.TreeView treeview;
        private Gtk.TreeStore store;
        private Gtk.TreeIter account_iter;

        private Granite.Widgets.CellRendererExpander cre;
        private Gtk.CellRendererText crt_balance_total;

        public Gee.ArrayList<Account> accounts { get; set; }

        public signal void list_account_selected (Account account);

        public Sidebar () {
            store = new Gtk.TreeStore(COLUMN_COUNT,
                typeof (string),
                typeof (Account),
                typeof (Icon),
                typeof (Action)
            );

            build_ui ();
        }

        public Sidebar.with_accounts (Gee.ArrayList<Account> accounts) {
            this ();
            this.accounts = accounts;
            update_view ();
        }

        private void build_ui () {

            debug ("sidebar: build ui");

            vexpand = true;
            vexpand_set = true;

            treeview = new Gtk.TreeView ();
            treeview.set_headers_visible (false);
            treeview.show_expanders = false;
            treeview.model = store;
            treeview.level_indentation = 10;
            treeview.activate_on_single_click = true;
            treeview.vexpand = true;
            treeview.vexpand_set = true;

            // style
            var style_context = treeview.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
            style_context.add_class (Granite.StyleClass.SOURCE_LIST);

            // selection
            var selection = treeview.get_selection ();
            selection.set_mode (Gtk.SelectionMode.BROWSE);

            var col = new Gtk.TreeViewColumn ();
            col.max_width = -1;
            col.expand = true;
            col.spacing = 3;

            var crt = new Gtk.CellRendererText ();
            col.pack_start (crt, true);
            crt.editable = false;
            crt.editable_set = true;
            crt.xpad = 10;

            col.set_attributes (crt, "text", Column.LABEL);
            col.set_cell_data_func (crt, treeview_text_renderer_function);

            cre = new Granite.Widgets.CellRendererExpander ();
            cre.is_category_expander = true;
            cre.xalign = (float) 1.0;
            col.pack_end (cre, false);
            col.set_cell_data_func (cre, treeview_expander_renderer_function);

            crt_balance_total = new Gtk.CellRendererText ();
            crt_balance_total.editable = false;
            crt_balance_total.editable_set = true;
            crt_balance_total.xalign = (float) 1.0;
            crt_balance_total.size_points = 8;
            crt_balance_total.size_set = true;
            col.pack_end (crt_balance_total, false);
            col.set_cell_data_func (crt_balance_total, treeview_text_renderer_balance_total_function);

            add (treeview);

            treeview.append_column (col);

            treeview.get_selection ().changed.connect (treeview_row_activated);

            treeview.show_all ();

            width_request = 250;

            show_all ();
        }

        public void update_view () {

            debug ("sidebar: update view");

            store.clear ();

            // Add "Accounts" category header
            account_iter = add_item (null, _("Accounts"), null);

            if (accounts != null) {

                foreach (Account account in accounts) {
                    add_item (account_iter, account.number, account);
                }
            }

            // Add "Add account..."
            add_item (account_iter, _("Add account\u2026"), null, Action.ADD_ACCOUNT);

            treeview.expand_all ();
        }

        private Gtk.TreeIter add_item (Gtk.TreeIter? parent, string label, Account? account, Action action = Action.NONE) {

            Gtk.TreeIter iter;

            store.append(out iter, parent);

            store.@set (iter, Column.LABEL, label,
                Column.ACCOUNT, account,
                Column.ICON, null,
                Column.ACTION, action, -1);

            return iter;
        }

        private void treeview_text_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;
            Account? account = null;
            Action action;

            model.@get (iter, Column.ACCOUNT, out account, -1);
            model.@get (iter, Column.ACTION, out action, -1);

            if (account == null && action == Action.NONE) {
                // category name
                crt.weight = 900;
                crt.weight_set = true;
                crt.height = 20;
            }
            else {
                crt.height = -1;
                crt.weight_set = false;
            }
        }

        private void treeview_expander_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Granite.Widgets.CellRendererExpander cre = renderer as Granite.Widgets.CellRendererExpander;
            Account? account = null;

            model.@get (iter, Column.ACCOUNT, out account, -1);

            if (account == null) {
                // category name
                cre.visible = true;
            }
            else {
                cre.visible = false;
            }
        }

        private void treeview_text_renderer_balance_total_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;
            Account? account = null;
            Action action;

            model.@get (iter, Column.ACCOUNT, out account, -1);
            model.@get (iter, Column.ACTION, out action, -1);

            if (account == null && action == Action.NONE) {
                //
                crt.visible = true;

                // calculate balance for all accounts
                var balance = 0d;

                foreach (Account a in accounts) {
                    balance += a.balance;
                }

                crt.text = Envelope.Util.format_currency (balance);
                crt.foreground = balance < 0 ? COLOR_SUBZERO : COLOR_ZERO;
            }
            else if (account != null) {
                crt.visible = true;
                crt.text = Envelope.Util.format_currency (account.balance);
                crt.foreground = account.balance < 0 ? COLOR_SUBZERO : COLOR_ZERO;
            }
            else {
                crt.visible = false;
            }

        }

        private void treeview_row_activated () {

            Gtk.TreeIter iter;
            Gtk.TreeModel model;

            if (treeview.get_selection ().get_selected (out model, out iter)) {

                Account account;
                Action action;

                model.@get (iter, Column.ACCOUNT, out account, -1);
                model.@get (iter, Column.ACTION, out action, -1);

                if (account != null) {
                    account_selected (account);
                }
                else {
                    toggle_selected_row_expansion ();
                }

                debug ("action is %s".printf (action.to_string ()));

                if (action != Action.NONE) {
                    switch (action) {
                        case Action.ADD_ACCOUNT:
                            var dialog = new AddAccountDialog ();
                            dialog.account_created.connect (s_account_created);
                            dialog.show_all ();
                            break;

                        default:
                            assert_not_reached ();
                    }
                }

            }
        }

        public void s_account_created (Account account) {
            add_account (account);
        }

        private void add_account (Account account) {
            accounts.add (account);
            update_view ();
        }

        private void toggle_selected_row_expansion () {
            if (cre.visible) {

                var path = get_selected_path ();

                if (path != null) {

                    if (treeview.is_row_expanded (path)) {
                        treeview.collapse_row (path);
                    }
                    else {
                        treeview.expand_row (path, false);
                    }
                }
            }
        }

        private void account_selected (Account account) {
            debug ("sidebar account selected : %s".printf (account.number));
            list_account_selected (account);
        }

        private Gtk.TreePath? get_selected_path () {

            Gtk.TreeModel model;
            var paths = treeview.get_selection ().get_selected_rows (out model);

            if (paths.length () == 1) {
                return paths.nth_data (0);
            }

            return null;
        }

    }
}
