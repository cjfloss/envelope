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

using Envelope.DB;
using Envelope.Dialog;
using Envelope.Widget;
using Envelope.Service;
using Envelope.Service.Settings;

namespace Envelope.View {

    private static Sidebar sidebar_instance = null;

    public class Sidebar : Gtk.ScrolledWindow {

        public static new unowned Sidebar get_default () {
            if (sidebar_instance == null) {
                sidebar_instance = new Sidebar ();
            }

            return sidebar_instance;
        }

        private static const int COLUMN_COUNT = 8;

        private static const string ICON_ACCOUNT    = "accessories-calculator-symbolic";
        private static const string ICON_OUTFLOW    = "go-up-symbolic";
        private static const string ICON_INFLOW     = "go-down-symbolic";
        private static const string ICON_REMAINING  = "view-refresh-symbolic";
        private static const string ICON_CATEGORY   = "folder-symbolic";

        private enum Action {
            NONE,
            ADD_ACCOUNT,
            ADD_CATEGORY
        }

        private enum Column {
            LABEL,
            ACCOUNT,
            ICON,
            ACTION,
            DESCRIPTION,
            CATEGORY,
            STATE,
            TREE_CATEGORY
        }

        private enum TreeCategory {
            OVERVIEW,
            ACCOUNTS,
            CATEGORIES
        }

        private static const string COLOR_SUBZERO = "#A62626";
        private static const string COLOR_ZERO = "#4e9a06";

        private Gtk.TreeView treeview;
        private Gtk.TreeStore store;
        private Gtk.TreeIter account_iter;
        private Gtk.TreeIter category_iter;

        private Granite.Widgets.CellRendererExpander cre;
        private Gtk.CellRendererText crt_balance_total;

        public Gee.ArrayList<Account> accounts { get; set; }

        public BudgetState budget_state { get; set; }

        private int current_account_id;

        public signal void list_account_selected (Account account);
        public signal void list_account_name_updated (Account account, string new_name);

        public Sidebar () {
            store = new Gtk.TreeStore(COLUMN_COUNT,
                typeof (string),
                typeof (Account),
                typeof (string),
                typeof (Action),
                typeof (string),
                typeof (Category),
                typeof (string),
                typeof (TreeCategory)
            );

            build_ui ();
            connect_signals ();

            sidebar_instance = this;
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
            treeview.tooltip_column = Column.DESCRIPTION;

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

            var crs = new Gtk.CellRendererText ();
            col.pack_start (crs, false);

            var cri = new Gtk.CellRendererPixbuf ();
            col.pack_start (cri, false);
            col.set_attributes (cri, "icon-name", Column.ICON);
            col.set_cell_data_func (cri, treeview_icon_renderer_function);

            var crt = new Gtk.CellRendererText ();
            col.pack_start (crt, true);
            crt.editable = true;
            crt.editable_set = true;
            crt.ellipsize = Pango.EllipsizeMode.END;
            crt.ellipsize_set = true;
            crt.edited.connect (account_renamed);

            col.set_attributes (crt, "text", Column.LABEL);
            col.set_cell_data_func (crt, treeview_text_renderer_function);

            cre = new Granite.Widgets.CellRendererExpander ();
            //cre.is_category_expander = true;
            cre.xalign = (float) 1.0;
            col.pack_end (cre, false);
            col.set_cell_data_func (cre, treeview_expander_renderer_function);

            crt_balance_total = new Gtk.CellRendererText ();
            crt_balance_total.editable = false;
            crt_balance_total.editable_set = true;
            crt_balance_total.xalign = (float) 1.0;
            crt_balance_total.size_points = 8;
            crt_balance_total.size_set = true;
            crt_balance_total.ellipsize = Pango.EllipsizeMode.NONE;
            crt_balance_total.ellipsize_set = true;
            col.pack_end (crt_balance_total, false);
            col.set_cell_data_func (crt_balance_total, treeview_text_renderer_balance_total_function);

            add (treeview);

            treeview.append_column (col);
            treeview.show_all ();

            treeview.get_selection ().changed.connect (treeview_row_activated);

            //width_request = 150;
        }

        private void connect_signals () {
            var dbm = DatabaseManager.get_default ();

            // add account to list when a new account is added in the database
            dbm.account_created.connect (add_new_account);

            destroy.connect (on_quit);
        }

        public void update_view () {

            debug ("sidebar: update view");

            store.clear ();

            try {
                budget_state = BudgetManager.get_default ().compute_current_state ();

                var overview_iter = add_item (null, _("Overview"), TreeCategory.OVERVIEW, null, null, Action.NONE);

                add_item (overview_iter, _("Spending this month"), TreeCategory.OVERVIEW, null, null, Action.NONE, budget_state.outflow, ICON_OUTFLOW);
                add_item (overview_iter, _("Income this month"), TreeCategory.OVERVIEW, null, null, Action.NONE, budget_state.inflow, ICON_INFLOW);
                add_item (overview_iter, _("Remaining"), TreeCategory.OVERVIEW, null, null, Action.NONE, budget_state.inflow - budget_state.outflow, ICON_REMAINING);

                // Add "Accounts" category header
                account_iter = add_item (null, _("Accounts"), TreeCategory.ACCOUNTS, null, null);

                if (accounts != null) {

                    foreach (Account account in accounts) {
                        add_item (account_iter, account.number, TreeCategory.ACCOUNTS, account, null, Action.NONE, null, ICON_ACCOUNT);
                    }
                }

                // Add "Add account..."
                add_item (account_iter, _("Add account\u2026"), TreeCategory.ACCOUNTS, null, null, Action.ADD_ACCOUNT);

                // Add "Categories" category header
                category_iter = add_item (null, _("Spending categories"), TreeCategory.CATEGORIES, null, null);

                // Add mocked categories

                var cat = new Category ();

                add_item (category_iter, _("Groceries"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Fuel"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Public transit"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Restaurants"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Entertainment"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Savings"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Personal care"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Alcohol & Bars"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Emergency fund"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);
                add_item (category_iter, _("Cigarettes"), TreeCategory.CATEGORIES, null, cat, Action.NONE, null, ICON_CATEGORY);

                // Add "Add category..."
                add_item (category_iter, _("Add category\u2026"), TreeCategory.CATEGORIES, null, null, Action.ADD_CATEGORY);
            }
            catch (ServiceError err) {
                error (err.message);
            }

            treeview.expand_all ();
        }

        private Gtk.TreeIter add_item (Gtk.TreeIter? parent,
                                        string label,
                                        TreeCategory tree_category,
                                        Account? account,
                                        Category? category,
                                        Action action = Action.NONE,
                                        double? state_amount = null,
                                        string? icon = null) {

            Gtk.TreeIter iter;

            store.append(out iter, parent);

            store.@set (iter, Column.LABEL, label,
                Column.ACCOUNT, account,
                Column.ICON, icon,
                Column.ACTION, action,
                Column.DESCRIPTION, account != null ? account.description : null,
                Column.CATEGORY, category,
                Column.STATE, state_amount,
                Column.TREE_CATEGORY, tree_category, -1);

            return iter;
        }

        private void treeview_text_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;
            Account? account = null;
            Category? category = null;
            Action action;
            double? state = null;
            TreeCategory tree_category;

            model.@get (iter, Column.ACCOUNT, out account, -1);
            model.@get (iter, Column.ACTION, out action, -1);
            model.@get (iter, Column.CATEGORY, out category, -1);
            model.@get (iter, Column.STATE, out state, -1);
            model.@get (iter, Column.TREE_CATEGORY, out tree_category, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    if (state == null) {
                        crt.weight = 900;
                        crt.weight_set = true;
                        crt.height = 20;
                        crt.editable = false;
                        crt.editable_set = true;
                    }
                    else {
                        crt.weight_set = false;
                        crt.editable = false;
                        crt.editable_set = true;
                    }
                    break;

                case TreeCategory.ACCOUNTS:
                    if (account == null && action == Action.NONE) {
                        crt.weight = 900;
                        crt.weight_set = true;
                        crt.height = 20;
                        crt.editable = false;
                        crt.editable_set = true;
                    }
                    else {
                        crt.weight_set = false;
                        crt.editable = true;
                        crt.editable_set = true;
                    }
                    break;

                case TreeCategory.CATEGORIES:
                    if (category == null && action == Action.NONE) {
                        crt.weight = 900;
                        crt.weight_set = true;
                        crt.height = 20;
                        crt.editable = false;
                        crt.editable_set = true;
                    }
                    else {
                        crt.weight_set = false;
                        crt.editable = true;
                        crt.editable_set = true;
                    }
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void treeview_icon_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererPixbuf crp = renderer as Gtk.CellRendererPixbuf;
            string? icon_name = null;

            model.@get (iter, Column.ICON, out icon_name, -1);

            if (icon_name != null) {
                crp.visible = true;
            }
            else {
                crp.visible = false;
            }
        }

        private void treeview_expander_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Granite.Widgets.CellRendererExpander cre = renderer as Granite.Widgets.CellRendererExpander;
            Account? account = null;
            Category? category = null;

            model.@get (iter, Column.ACCOUNT, out account, -1);
            model.@get (iter, Column.CATEGORY, out category, -1);

            if (account == null && category == null) {
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
            Category? category = null;
            Action action;
            double? state = null;
            TreeCategory tree_category;

            model.@get (iter, Column.ACCOUNT, out account, -1);
            model.@get (iter, Column.ACTION, out action, -1);
            model.@get (iter, Column.CATEGORY, out category, -1);
            model.@get (iter, Column.STATE, out state, -1);
            model.@get (iter, Column.TREE_CATEGORY, out tree_category, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    crt.visible = true;

                    if (state == null) {
                        crt.text = new DateTime.now_local ().format ("%B %Y");
                        crt.foreground_set = false;
                    }
                    else {
                        crt.text = Envelope.Util.format_currency (state);
                        crt.foreground = state < 0 ? COLOR_SUBZERO : COLOR_ZERO;
                    }

                    break;

                case TreeCategory.ACCOUNTS:
                    if (account == null && action == Action.NONE) {
                        crt.visible = accounts == null || accounts.size == 0;

                        if (crt.visible) {
                            var balance = 0d;

                            foreach (Account a in accounts) {
                                balance += a.balance;
                            }

                            crt.weight_set = false;
                            crt.text = Envelope.Util.format_currency (balance);
                            crt.foreground = balance < 0 ? COLOR_SUBZERO : COLOR_ZERO;
                        }
                        else {
                            crt.weight_set = false;
                        }
                    }
                    else if (account != null) {
                        crt.visible = true;
                        crt.weight_set = false;
                        crt.text = Envelope.Util.format_currency (account.balance);
                        crt.foreground = account.balance < 0 ? COLOR_SUBZERO : COLOR_ZERO;
                    }
                    else {
                        crt.visible = false;
                        crt.weight_set = false;
                    }
                    break;

                case TreeCategory.CATEGORIES:
                    crt.visible = false;
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void treeview_row_activated () {

            debug ("row activated!");

            Gtk.TreeIter iter;
            Gtk.TreeModel model;

            if (treeview.get_selection ().get_selected (out model, out iter)) {

                Account account;
                Action action;

                model.@get (iter, Column.ACCOUNT, out account, -1);
                model.@get (iter, Column.ACTION, out action, -1);

                if (account != null) {
                    debug ("account_selected");
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
            select_account (account);
        }

        public void add_account (Account account) {
            accounts.add (account);
            update_view ();
        }

        public void add_new_account (Account account) {
            add_account (account);
            select_account (account);
        }

        public void select_account (Account account) {
            Gtk.TreeIter? iter;
            get_account_iter (account, out iter);

            if (iter != null) {
                treeview.get_selection ().select_iter (iter);
                account_selected (account);
            }
        }

        private void get_account_iter (Account account, out Gtk.TreeIter iter) {

            debug ("looking for tree iterator matching account %d".printf (account.@id));

            Gtk.TreeIter? found_iter = null;
            int id = account.@id;

            store.@foreach ((model, path, fe_iter) => {

                Account val;

                model.@get (fe_iter, Column.ACCOUNT, out val, -1);

                if (val != null && val.@id == id) {
                    found_iter = fe_iter;
                    return true;
                }

                return false;
            });

            iter = found_iter;
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

            current_account_id = account.@id;

            list_account_selected (account);
        }

        private void account_renamed (string path, string text) {
            Gtk.TreeIter iter;

            if (store.get_iter_from_string (out iter, path)) {
                string old_name = "";
                Account account;

                store.@get (iter, Column.LABEL, out old_name,
                    Column.ACCOUNT, out account, -1);

                debug ("account '%s' renamed to '%s'".printf (old_name, text));

                store.@set (iter, Column.LABEL, text, -1);

                // fire signal list_account_name_updated
                list_account_name_updated (account, text);
            }
        }

        private Gtk.TreePath? get_selected_path () {

            Gtk.TreeModel model;
            var paths = treeview.get_selection ().get_selected_rows (out model);

            if (paths.length () == 1) {
                return paths.nth_data (0);
            }

            return null;
        }

        private void on_quit () {
            var saved_state = SavedState.get_default ();
            saved_state.selected_account_id = current_account_id;
        }

    }
}
