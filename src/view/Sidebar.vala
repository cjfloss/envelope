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

    public class Sidebar : Gtk.ScrolledWindow {

        private static Sidebar sidebar_instance = null;

        public static new Sidebar get_default () {
            if (sidebar_instance == null) {
                sidebar_instance = new Sidebar ();
            }

            return sidebar_instance;
        }

        private static const int COLUMN_COUNT = 11;

        private static const string ICON_ACCOUNT    = "text-spreadsheet";
        private static const string ICON_OUTFLOW    = "go-up-symbolic";
        private static const string ICON_INFLOW     = "go-down-symbolic";
        private static const string ICON_REMAINING  = "view-refresh-symbolic";
        private static const string ICON_CATEGORY   = "applications-mail";
        private static const string ICON_ACTION_ADD = "tab-new-symbolic";

        private enum Action {
            NONE,
            ADD_ACCOUNT,
            ADD_CATEGORY,
            SHOW_OVERVIEW
        }

        private enum Column {
            LABEL,
            ACCOUNT,
            ICON,
            ACTION,
            DESCRIPTION,
            CATEGORY,
            STATE,
            TREE_CATEGORY,
            IS_HEADER,
            COLORIZE,
            TOOLTIP
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
        private Gtk.TreeIter overview_iter;
        private Gtk.TreeIter overview_inflow_iter;
        private Gtk.TreeIter overview_outflow_iter;
        private Gtk.TreeIter overview_remaining_iter;

        private Granite.Widgets.CellRendererExpander cre;
        private Gtk.CellRendererText crt_balance_total;

        public Gee.ArrayList<Account> accounts { get; set; }

        public BudgetState budget_state { get; set; }

        public Account selected_account { get; private set; }

        private int current_account_id;

        public signal void overview_selected ();
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
                typeof (TreeCategory),
                typeof (bool),
                typeof (bool),
                typeof (string)
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
            treeview.fixed_height_mode = true;
            treeview.tooltip_column = Column.TOOLTIP;

            // style
            var style_context = treeview.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
            style_context.add_class (Granite.StyleClass.SOURCE_LIST);

            // selection
            var selection = treeview.get_selection ();
            selection.set_mode (Gtk.SelectionMode.BROWSE);

            var col = new Gtk.TreeViewColumn ();
            col.max_width = -1;
            col.sizing = Gtk.TreeViewColumnSizing.FIXED;
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

            col.set_attributes (crt, "markup", Column.LABEL);
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
            crt_balance_total.ellipsize = Pango.EllipsizeMode.NONE;
            crt_balance_total.ellipsize_set = true;
            crt_balance_total.edited.connect (balance_edited);
            col.pack_end (crt_balance_total, true);
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

            BudgetManager.get_default ().budget_changed.connect (update_view);
            BudgetManager.get_default ().category_added.connect (update_view);
            AccountManager.get_default ().account_updated.connect (update_account_item);

            destroy.connect (on_quit);
        }

        public void update_view () {

            debug ("sidebar: update view");

            store.clear ();

            var budget_state = BudgetManager.get_default ().state;
            var remaining = Math.fabs (budget_state.inflow) - Math.fabs (budget_state.outflow);

            var month_label = new DateTime.now_local ().format ("%B %Y");

            debug ("remaining: %f", remaining);

            overview_iter = add_item (null, _("Your budget"), TreeCategory.OVERVIEW, null, null, Action.SHOW_OVERVIEW, null, null, true,
                false, "Budget overview for %s".printf (month_label));

            overview_outflow_iter = add_item (null, _("Spending this month"), TreeCategory.OVERVIEW, null, null, Action.SHOW_OVERVIEW, budget_state.outflow, ICON_OUTFLOW, false, false,
                "Money spent in %s".printf (month_label));

            overview_inflow_iter = add_item (null, _("Income this month"), TreeCategory.OVERVIEW, null, null, Action.SHOW_OVERVIEW, budget_state.inflow, ICON_INFLOW, false, false,
                "Money earned in %s".printf (month_label));

            overview_remaining_iter = add_item (null, _("Remaining"), TreeCategory.OVERVIEW, null, null, Action.SHOW_OVERVIEW, remaining, ICON_REMAINING, false, true,
                "Remaining balance for %s".printf (month_label));

            // Add "Accounts" category header
            account_iter = add_item (null, _("Accounts"), TreeCategory.ACCOUNTS, null, null, Action.NONE, null, null, true);

            try {

                Gee.ArrayList<Account> account_list = AccountManager.get_default ().get_accounts ();

                if (account_list != null && !account_list.is_empty) {

                    foreach (Account account in accounts) {
                        debug ("adding account %s".printf (account.number));
                        add_item (account_iter, account.number, TreeCategory.ACCOUNTS, account, null, Action.NONE, null, ICON_ACCOUNT, false, true,
                            account.description != null ? "%s - %s".printf (account.number, account.description) : account.number);
                    }
                }

            }
            catch (ServiceError err) {
                error ("could not load accounts (%s)".printf (err.message));
            }

            // Add "Add account..."
            add_item (account_iter, _("Add account\u2026"), TreeCategory.ACCOUNTS, null, null, Action.ADD_ACCOUNT, null, ICON_ACTION_ADD);

            // Add "Categories" category header
            category_iter = add_item (null, _("Spending categories"), TreeCategory.CATEGORIES, null, null, Action.NONE, null, null, true);

            // Add categories
            try {
                Gee.ArrayList<Category> categories = BudgetManager.get_default ().get_categories ();

                foreach (Category category in categories) {
                    debug ("adding category %s".printf (category.name));

                    double cat_inflow;
                    double cat_outflow;
                    BudgetManager.get_default ().compute_current_category_operations (category, out cat_inflow, out cat_outflow);

                    debug ("category inflow: %f, category outflow: %f", cat_inflow, cat_outflow);

                    add_item (category_iter, category.name, TreeCategory.CATEGORIES, null, category, Action.NONE, cat_inflow - cat_outflow, ICON_CATEGORY);
                }
            }
            catch (ServiceError err) {
                error (err.message);
            }

            // Add "Add category..."
            add_item (category_iter, _("Add category\u2026"), TreeCategory.CATEGORIES, null, null, Action.ADD_CATEGORY, null, ICON_ACTION_ADD);
            
            treeview.get_selection ().unselect_all ();
            treeview.expand_all ();
        }

        public void s_account_created (Account account) {
            add_new_account (account);
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

            if (get_account_iter (account, out iter)) {
                treeview.get_selection ().select_iter (iter);
                account_selected (account);
            }
        }

        private void update_budget_section () {

            debug ("updating budget section");

            var budget_state = BudgetManager.get_default ().state;
            var remaining = Math.fabs (budget_state.inflow) - Math.fabs (budget_state.outflow);

            store.@set (overview_inflow_iter, Column.STATE, Envelope.Util.String.format_currency (budget_state.inflow), -1);
            store.@set (overview_outflow_iter, Column.STATE, Envelope.Util.String.format_currency (budget_state.outflow), -1);
            store.@set (overview_remaining_iter, Column.STATE, Envelope.Util.String.format_currency (remaining), -1);
        }

        private void update_accounts_section () {

            try {

                Gee.ArrayList<Account> account_list = AccountManager.get_default ().get_accounts ();

                if (account_list != null && !account_list.is_empty) {

                    foreach (Account account in accounts) {
                        update_account_item (account);
                    }
                }

            }
            catch (ServiceError err) {
                error ("could not load accounts (%s)".printf (err.message));
            }

        }

        /**
         * Find the item in the tree which corresponds to account and update the account instance in the store
         */
        private void update_account_item (Account account) {

            Gtk.TreeIter iter;

            if (get_account_iter (account, out iter)) {
                store.@set (iter, Column.ACCOUNT, account, -1);
            }
        }

        private void update_categories_section () {

        }

        private Gtk.TreeIter add_item (Gtk.TreeIter? parent,
                                        string label,
                                        TreeCategory tree_category,
                                        Account? account,
                                        Category? category,
                                        Action action = Action.NONE,
                                        double? state_amount = null,
                                        string? icon = null,
                                        bool is_header = false,
                                        bool colorize = false,
                                        string tooltip = "") {

            Gtk.TreeIter iter;

            store.append(out iter, parent);

            var state_currency = "";
            if (state_amount != null) {
                state_currency = Envelope.Util.String.format_currency (state_amount);
                debug ("state_currency: %s", state_currency);
            }

            store.@set (iter, Column.LABEL, label,
                Column.ACCOUNT, account,
                Column.ICON, icon,
                Column.ACTION, action,
                Column.DESCRIPTION, account != null ? account.description : null,
                Column.CATEGORY, category,
                Column.STATE, state_currency,
                Column.TREE_CATEGORY, tree_category,
                Column.IS_HEADER, is_header,
                Column.COLORIZE, colorize,
                Column.TOOLTIP, tooltip != "" ? tooltip : label, -1);

            return iter;
        }

        private void treeview_text_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;
            Account? account = null;
            Category? category = null;
            Action action;
            double? state = null;
            TreeCategory tree_category;
            bool is_header;

            model.@get (iter,
                Column.ACCOUNT, out account,
                Column.ACTION, out action,
                Column.CATEGORY, out category,
                Column.STATE, out state,
                Column.TREE_CATEGORY, out tree_category,
                Column.IS_HEADER, out is_header, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:

                    crt.editable = false;
                    crt.editable_set = true;

                    if (is_header) {
                        crt.weight = 900;
                        crt.weight_set = true;
                        crt.height = 20;
                    }
                    else {
                        crt.weight_set = false;
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

            crp.visible = icon_name != null;
        }

        private void treeview_expander_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            bool is_header;
            TreeCategory category;

            model.@get (iter,
                Column.IS_HEADER, out is_header,
                Column.TREE_CATEGORY, out category, -1);

            renderer.visible = is_header && category != TreeCategory.OVERVIEW;
        }

        private void treeview_text_renderer_balance_total_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;

            crt.editable = false;
            crt.editable_set = true;

            Account? account = null;
            Category? category = null;
            Action action;
            string state;
            TreeCategory tree_category;
            bool is_header;
            bool colorize;

            model.@get (iter,
                Column.ACCOUNT, out account,
                Column.ACTION, out action,
                Column.CATEGORY, out category,
                Column.STATE, out state,
                Column.TREE_CATEGORY, out tree_category,
                Column.IS_HEADER, out is_header,
                Column.COLORIZE, out colorize, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    crt.visible = true;
                    crt.weight_set = false;

                    if (is_header) {
                        crt.text = new DateTime.now_local ().format ("%B %Y");
                        crt.foreground_set = false;
                    }
                    else {
                        crt.text = state;

                        try {

                            double parsed_state = Envelope.Util.String.parse_currency (state);

                            if (colorize && parsed_state < 0) {
                                crt.foreground = COLOR_SUBZERO;
                                crt.foreground_set = true;
                            }
                            else {
                                crt.foreground_set = false;
                            }
                        }
                        catch (Envelope.Util.String.ParseError err) {
                            assert_not_reached ();
                        }
                    }

                    break;

                case TreeCategory.ACCOUNTS:
                    if (account == null && action == Action.NONE) {
                        crt.visible = accounts == null || accounts.is_empty;

                        if (crt.visible) {
                            var balance = 0d;

                            foreach (Account a in accounts) {
                                balance += a.balance;
                            }

                            crt.weight_set = false;
                            crt.text = Envelope.Util.String.format_currency (balance);

                            if (balance < 0) {
                                crt.foreground = COLOR_SUBZERO;
                                crt.foreground_set = true;
                            }
                            else {
                                crt.foreground_set = false;
                            }
                        }
                        else {
                            crt.weight_set = false;
                        }
                    }
                    else if (account != null) {
                        crt.visible = true;
                        crt.weight_set = false;
                        crt.text = Envelope.Util.String.format_currency (account.balance);
                        crt.editable = true;
                        crt.editable_set = true;

                        if (account.balance < 0) {
                            crt.foreground = COLOR_SUBZERO;
                            crt.foreground_set = true;
                        }
                        else {
                            crt.foreground_set = false;
                        }
                    }
                    else {
                        crt.visible = false;
                        crt.weight_set = false;
                    }
                    break;

                case TreeCategory.CATEGORIES:

                    if (state != "") {
                        crt.text = state;
                        crt.visible = true;
                    }
                    else {
                        crt.visible = false;
                    }
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void balance_edited (string path, string new_text) {

            try {

                // parse first; if it fails, nothing expensive below will be executed
                double amount = Envelope.Util.String.parse_currency (new_text);

                Gtk.TreeIter iter;
                if (store.get_iter_from_string (out iter, path)) {

                    Account account;
                    store.@get (iter, Column.ACCOUNT, out account, -1);

                    assert (account != null);

                    account.balance = amount;

                    AccountManager.get_default ().update_account_balance (ref account);
                }
                else {
                    assert_not_reached (); // should never land here!
                }

            }
            catch (Envelope.Util.String.ParseError err) {
                warning ("could not update account balance (%s)".printf (err.message));
            }
            catch (ServiceError err) {
                warning ("could not update account balance (%s)".printf (err.message));
            }
        }

        private void treeview_row_activated () {

            Gtk.TreeIter iter;
            Gtk.TreeModel model;

            if (treeview.get_selection ().get_selected (out model, out iter)) {

                Account account;
                Action action;
                TreeCategory tree_category;

                model.@get (iter,
                    Column.ACCOUNT, out account,
                    Column.ACTION, out action,
                    Column.TREE_CATEGORY, out tree_category, -1);

                if (account != null) {
                    account_selected (account);
                }
                else if (action == Action.NONE) {
                    toggle_selected_row_expansion ();
                }

                switch (action) {
                    case Action.ADD_ACCOUNT:
                        var dialog = new AddAccountDialog ();
                        dialog.account_created.connect (s_account_created);
                        dialog.show_all ();
                        break;

                    case Action.SHOW_OVERVIEW:
                        overview_selected ();
                        break;

                    case Action.NONE:
                        break;

                    default:
                        assert_not_reached ();
                }
            }
        }

        private void account_selected (Account account) {
            debug ("sidebar account selected : %s".printf (account.number));

            current_account_id = account.@id;
            selected_account = account;

            list_account_selected (account);
        }

        private bool get_account_iter (Account account, out Gtk.TreeIter iter) {

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

            return found_iter != null;
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

        private void account_renamed (string path, string text) {
            Gtk.TreeIter iter;

            if (store.get_iter_from_string (out iter, path)) {

                Account account;
                store.@get (iter, Column.ACCOUNT, out account, -1);

                store.@set (iter,
                    Column.LABEL, text,
                    Column.TOOLTIP, account.description != null ? "%s - %s".printf (text, account.description) : text, -1);

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
