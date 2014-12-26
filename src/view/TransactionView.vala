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
using Envelope.Widget;
using Envelope.Service;
using Envelope.Dialog;

namespace Envelope.View {

    public class TransactionView : Gtk.Box {

        private static TransactionView transaction_view_instance = null;

        public static new TransactionView get_default () {
            if (transaction_view_instance == null) {
                transaction_view_instance = new TransactionView ();
            }

            return transaction_view_instance;
        }

        private enum Column {
            DATE,
            MERCHANT,
            OUTFLOW,
            INFLOW,
            MEMO,
            ID,
            TRANSACTION,
            CATEGORY
        }

        private enum AddTransactionAction {
            NONE,
            EDITING
        }

        private static const int COLUMN_COUNT = 8;
        private static const string CELL_COLOR_INCOMING = "#4e9a06";
        private static const string CELL_COLOR_OUTGOING = "#A62626";
        private static string CELL_DATE_FORMAT = Granite.DateTime.get_default_date_format (false, true, true);

        private Gtk.TreeView treeview;
        private Gtk.Box filter_box;
        private Gtk.ScrolledWindow grid_scroll;
        private Gtk.Box scroll_box;

        private CellRendererDatePicker crdp;
        private Gtk.CellRendererText renderer_memo;

        // filter widgets
        private Gtk.Button btn_add_transaction;
        private Gtk.ButtonBox add_transaction_button_box;
        private Gtk.InfoBar infobar;

        private Gtk.TreeStore transactions_store;
        private Gtk.TreeModelFilter view_store;
        private Gtk.TreeIter current_editing_iter;

        private bool populating_from_list = false;

        private DateTime now = new DateTime.now_local ();
        private DateTime filter_from = null;
        private DateTime filter_to = null;

        private AddTransactionAction current_add_transaction_action = AddTransactionAction.NONE;

        private Gtk.Menu right_click_menu;
        private Gtk.MenuItem right_click_menu_item_split;
        private Gtk.MenuItem right_click_menu_item_remove;

        public string search_term { get; set; }

        public Gee.ArrayList<Transaction> transactions { get; set; }

        private TransactionView () {

            Object (orientation: Gtk.Orientation.VERTICAL);

            transactions_store = new Gtk.TreeStore(COLUMN_COUNT,
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (int),
                typeof (Transaction),
                typeof (string)); // todo change to category type

            view_store = new Gtk.TreeModelFilter (transactions_store, null);
            view_store.set_visible_func (view_store_filter_func);

            build_ui ();
            connect_signals ();
            transaction_view_instance = this;
        }

        public void set_search_filter (string term) {
            search_term = term;
            apply_filters ();
        }

        public void add_transaction (Transaction transaction) {
            var in_amount = "";
            var out_amount = "";
            var formatted_amount = Envelope.Util.format_currency (transaction.amount);

            switch (transaction.direction) {
                case Transaction.Direction.INCOMING:
                in_amount = formatted_amount;
                break;

                case Transaction.Direction.OUTGOING:
                out_amount = formatted_amount;
                break;
            }

            Gtk.TreeIter iter;
            Gtk.TreeIter? parent_iter = null;

            if (transaction.parent != null) {
                Transaction parent_transaction = transaction.parent;
                get_transaction_iter (parent_transaction, out parent_iter);
            }

            var category_name = "";
            if (transaction.category != null) {
                category_name = transaction.category.name;
            }

            transactions_store.append (out iter, parent_iter);
            transactions_store.@set (iter,
                Column.DATE, transaction.date.format (CELL_DATE_FORMAT),
                Column.MERCHANT, transaction.label,
                Column.OUTFLOW, out_amount,
                Column.INFLOW, in_amount,
                Column.MEMO, transaction.description,
                Column.ID, transaction.@id,
                Column.TRANSACTION, transaction,
                Column.CATEGORY, category_name, -1);

            update_view ();
        }

        public void clear () {
            transactions_store.clear ();
        }

        public void show_import_dialog () {
            new ImportTransactionsDialog ().execute ();
        }

        public void add_transaction_row () {
            switch (current_add_transaction_action) {

                case AddTransactionAction.NONE:
                // add a row
                current_editing_iter = add_empty_row ();
                treeview.get_selection ().select_iter (current_editing_iter);

                btn_add_transaction.get_style_context ().add_class("suggested-action");
                btn_add_transaction.label = _("Apply");
                //btn_add_transaction.sensitive = false;

                current_add_transaction_action = AddTransactionAction.EDITING;

                break;

                case AddTransactionAction.EDITING:
                save_transaction ();

                // restore previous state
                current_add_transaction_action = AddTransactionAction.NONE;
                btn_add_transaction.get_style_context ().remove_class("suggested-action");
                btn_add_transaction.label = _("Add transaction");
                break;

                default:
                assert_not_reached ();
            }
        }

        private bool view_store_filter_func (Gtk.TreeModel model, Gtk.TreeIter iter) {

            Transaction transaction;
            model.@get (iter, Column.TRANSACTION, out transaction, -1);

            if (transaction == null) {
                return true; //editing... always shown
            }

            var search = search_term != null && search_term.strip ().length > 0 ? search_term.up () : "";

            if (search.length > 0) {
                var label = transaction.label.up ();
                var desc = (transaction.description != null ? transaction.description : "").up ();

                if (label.index_of (search) == -1 && desc.index_of (search) == -1) {
                    return false;
                }
            }

            // no search, or transaction matches search, continue with dates
            var tdate = transaction.date;

            var is_after = filter_from != null ? tdate.compare (filter_from) >= 0 : true;
            var is_before = filter_to != null ? tdate.compare (filter_to) <= 0 : true;

            bool visible = is_after && is_before;

            return visible;
        }

        /**
         * Adds a list of transactions to the grid store
         */
        private void add_transactions () {

            populating_from_list = true;

            clear ();

            var total = transactions != null ? transactions.size : 0;
            var count = 0;

            if (transactions != null) {

                foreach (Transaction transaction in transactions) {
                    add_transaction (transaction);
                }
            }

            populating_from_list = false;
        }

        private void get_transaction_iter (Transaction transaction, out Gtk.TreeIter? iter) {

            debug ("looking for tree iterator matching transaction %d".printf (transaction.@id));

            Gtk.TreeIter? found_iter = null;
            int id = transaction.@id;

            transactions_store.@foreach ((model, path, fe_iter) => {

                int val_id;

                model.@get (fe_iter, Column.ID, out val_id, -1);

                if (val_id == id) {
                    found_iter = fe_iter;
                    return true;
                }

                return false;
            });

            iter = found_iter;
        }

        private void update_view () {

            if (transactions != null && !transactions.is_empty) {
                filter_box.show ();
            }
            else {
                filter_box.hide ();
            }
        }

        private void apply_filters () {
            add_transactions ();
        }

        private void build_ui () {

            debug ("building transaction view ui");

            width_request = 400;

            build_filter_ui ();
            build_transaction_grid_ui ();
        }

        private void build_filter_ui () {

            debug ("building filter ui");

            // filters
            filter_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            filter_box.border_width = 5;

            add (filter_box);

            filter_box.pack_start (FilterView.get_default ());
            filter_box.show_all ();

            // infobar shown when filters do not return any transaction
            infobar = new Gtk.InfoBar  ();
            infobar.message_type = Gtk.MessageType.WARNING;
            infobar.get_content_area ().add (new Gtk.Label(_("No results.")));

            // TEMP FIX add top border to info bar. Hard coded for now. Need to get the color value from the .warning class in gtk css
            Granite.Widgets.Utils.set_theming (infobar, "GtkInfoBar { border-top-color: #c09e42; border-top-width: 1px; border-top-style: solid; }",
                null,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            infobar.hide ();
            add (infobar);
        }

        private void build_transaction_grid_ui () {

            debug ("building transaction grid ui");

            grid_scroll = new Gtk.ScrolledWindow (null, null);
            grid_scroll.vexpand = true;
            grid_scroll.vexpand_set = true;
            grid_scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

            add (grid_scroll);

            scroll_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            Granite.Widgets.Utils.set_theming (scroll_box, "* { background-color: @base_color; }", null, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            grid_scroll.add (scroll_box);

            scroll_box.show_all ();

            var tree_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            scroll_box.pack_start (tree_box, false, false);

            treeview = new Gtk.TreeView ();

            /*
             According to gtktreeview.c:4801, treeview line color is based on the border-top-color
             CSS property for the GtkTreeView. Black is ugly, and elementary gtk theme doesn't provide
             a custom value, so let's specify a value here. Might propose this in elementary-gtk-theme.
             */
            Granite.Widgets.Utils.set_theming (treeview, "GtkTreeView { border-top-color: @border_color; }",
                null,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            tree_box.pack_start (treeview, false, false);
            tree_box.show_all ();

            btn_add_transaction = new Gtk.Button.with_label (_("Add transaction"));
            btn_add_transaction.show_all ();
            btn_add_transaction.expand = false;
            btn_add_transaction.clicked.connect (() => {

                switch (current_add_transaction_action) {

                    case AddTransactionAction.NONE:
                        // add a row
                        current_editing_iter = add_empty_row ();

                        // convert to child model iter
                        Gtk.TreeIter child_iter;
                        view_store.convert_child_iter_to_iter (out child_iter, current_editing_iter);
                        treeview.get_selection ().select_iter (child_iter);

                        btn_add_transaction.get_style_context ().add_class("suggested-action");
                        btn_add_transaction.label = _("Apply");

                        current_add_transaction_action = AddTransactionAction.EDITING;

                        break;

                    case AddTransactionAction.EDITING:
                        save_transaction ();

                        // restore previous state
                        current_add_transaction_action = AddTransactionAction.NONE;
                        btn_add_transaction.get_style_context ().remove_class("suggested-action");
                        btn_add_transaction.label = _("Add transaction");
                        break;

                    default:
                        assert_not_reached ();
                }
            });

            add_transaction_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            add_transaction_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            add_transaction_button_box.add (btn_add_transaction);
            add_transaction_button_box.set_spacing (10);
            add_transaction_button_box.border_width = 12;
            scroll_box.add (add_transaction_button_box);

            treeview.activate_on_single_click = true;
            treeview.reorderable = true;
            treeview.headers_clickable = true;
            treeview.show_expanders = true;
            treeview.rules_hint = true;
            treeview.enable_grid_lines = Gtk.TreeViewGridLines.BOTH;
            treeview.set_model (view_store);
            treeview.set_search_column (1);
            treeview.hadjustment.page_size = 10d;
            treeview.show_all ();

            // memo cell renderer
            renderer_memo = new Gtk.CellRendererText();
            renderer_memo.editable = true;
            renderer_memo.edited.connect ((path, text) => {

                Gtk.TreeIter iter;

                if (view_store.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    view_store.convert_iter_to_child_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.MEMO, text, -1);
                }
            });

            // label cell renderer
            var renderer_label = new CellRendererTextCompletion ();
            renderer_label.store = MerchantStore.get_default ();
            renderer_label.text_column = 0;
            renderer_label.editable = true;
            renderer_label.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;

                if (view_store.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    view_store.convert_iter_to_child_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.MERCHANT, text, -1);
                }
            });

            // category cell renderer
            var renderer_category = new CellRendererTextCompletion ();
            renderer_category.store = CategoryStore.get_default ();
            renderer_category.text_column = CategoryStore.Column.LABEL;
            renderer_category.editable = true;
            renderer_category.edited.connect ((path, text) => {

                if (text.strip () == "") {
                    return;
                }

                Gtk.TreeIter iter;

                if (view_store.get_iter_from_string (out iter, path)) {

                    var category = CategoryStore.get_default ().get_category_by_name (text);

                    if (category == null) {

                        info ("creating new category '%s'".printf (text));
                        // we must create a new category
                        try {
                            category = BudgetManager.get_default ().create_category (text);
                        }
                        catch (ServiceError err) {
                            error ("could not create category '%s' (%s)", text, err.message);
                        }
                    }

                    Gtk.TreeIter store_iter;
                    view_store.convert_iter_to_child_iter (out store_iter, iter);

                    // update transaction object
                    Transaction transaction;
                    transactions_store.@get (store_iter, Column.TRANSACTION, out transaction, -1);
                    transaction.category = category;

                    transactions_store.@set (store_iter, Column.CATEGORY, category != null ? category.name : "", -1);
                }
            });

            // cell renderer for outgoing transactions
            Gtk.CellRendererText renderer_out = new Gtk.CellRendererText();
            renderer_out.editable = true;
            renderer_out.foreground = CELL_COLOR_OUTGOING;
            renderer_out.xalign = 1.0f;
            renderer_out.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;

                if (view_store.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    view_store.convert_iter_to_child_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.OUTFLOW, Envelope.Util.format_currency (Envelope.Util.parse_currency (text)), -1);
                }
            });

            // cell renderer for incoming transactions
            Gtk.CellRendererText renderer_in = new Gtk.CellRendererText();
            renderer_in.editable = true;
            renderer_in.foreground = CELL_COLOR_INCOMING;
            renderer_in.xalign = 1.0f;
            renderer_in.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;

                if (view_store.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    view_store.convert_iter_to_child_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.INFLOW, Envelope.Util.format_currency (Envelope.Util.parse_currency (text)), -1);
                }
            });

            crdp = new CellRendererDatePicker (treeview);
            crdp.editable = true;
            crdp.editable_set = true;
            crdp.xalign = 1.0f;
            crdp.edited.connect ((path, text) => {

                if (crdp.date_selected) {

                    Gtk.TreeIter iter;

                    if (view_store.get_iter_from_string (out iter, path)) {

                        Gtk.TreeIter store_iter;
                        view_store.convert_iter_to_child_iter (out store_iter, iter);

                        transactions_store.@set (store_iter, Column.DATE, text, -1);
                    }
                }
            });

            var crb = new Gtk.CellRendererText ();
            crb.text = _("FUTURE");
            crb.size_points = 7;
            crb.size_set = true;
            crb.weight = 900;
            crb.weight_set = true;
            crb.foreground = "#8AADD4"; // from elementary gtk theme's @question_bg_color
            crb.variant = Pango.Variant.SMALL_CAPS;
            crb.variant_set = true;

            // columns
            var date_column = new Gtk.TreeViewColumn ();
            date_column.set_title (_("Date"));
            date_column.max_width = -1;
            date_column.pack_start (crdp, true);
            date_column.resizable = true;
            date_column.reorderable = true;
            date_column.sort_column_id = Column.DATE;
            //date_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            date_column.set_attributes (crdp, "text", Column.DATE);
            treeview.append_column (date_column);

            var merchant_column = new Gtk.TreeViewColumn ();
            merchant_column.set_title (_("Merchant"));
            merchant_column.max_width = -1;
            merchant_column.pack_start (renderer_label, true);
            merchant_column.resizable = true;
            merchant_column.reorderable = true;
            merchant_column.sort_column_id = Column.MERCHANT;
            //merchant_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            merchant_column.set_attributes (renderer_label, "text", Column.MERCHANT);
            treeview.append_column (merchant_column);

            var category_column = new Gtk.TreeViewColumn ();
            category_column.set_title (_("Category"));
            category_column.max_width = -1;
            category_column.pack_start (renderer_category, true);
            category_column.resizable = true;
            category_column.reorderable = true;
            //category_column.sort_column_id
            //category_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            category_column.set_attributes (renderer_category, "text", Column.CATEGORY);
            treeview.append_column (category_column);

            var out_column = new Gtk.TreeViewColumn ();
            out_column.set_title (_("Outflow"));
            out_column.max_width = -1;
            out_column.pack_start (renderer_out, true);
            out_column.resizable = true;
            out_column.reorderable = true;
            out_column.sort_column_id = Column.OUTFLOW;
            //out_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            out_column.set_attributes (renderer_out, "text", Column.OUTFLOW);
            treeview.append_column (out_column);

            var in_column = new Gtk.TreeViewColumn ();
            in_column.set_title (_("Inflow"));
            in_column.max_width = -1;
            in_column.pack_start (renderer_in, true);
            in_column.resizable = true;
            in_column.reorderable = true;
            in_column.sort_column_id = Column.INFLOW;
            //in_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            in_column.set_attributes (renderer_in, "text", Column.INFLOW);
            treeview.append_column (in_column);

            var memo_column = new Gtk.TreeViewColumn ();
            memo_column.set_title (_("Memo"));
            memo_column.max_width = -1;
            memo_column.pack_start (renderer_memo, true);
            memo_column.pack_end (crb, false);
            memo_column.resizable = true;
            memo_column.reorderable = true;
            memo_column.sort_column_id = Column.MEMO;
            //memo_column.sizing = Gtk.TreeViewColumnSizing.FIXED;
            memo_column.spacing = 10;
            memo_column.set_cell_data_func (crb, cell_renderer_badge_func);
            memo_column.set_attributes (renderer_memo, "text", Column.MEMO);
            treeview.append_column (memo_column);

            // right-click menu
            right_click_menu = new Gtk.Menu ();

            right_click_menu_item_split = new Gtk.MenuItem.with_label (_("Split"));
            right_click_menu.append (right_click_menu_item_split);

            right_click_menu_item_remove = new Gtk.MenuItem.with_label (_("Remove"));
            right_click_menu.append (right_click_menu_item_remove);

            right_click_menu.show_all ();

            grid_scroll.show_all ();
            treeview.show_all ();
            tree_box.show_all ();
        }

        private void cell_renderer_badge_func (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText cr = renderer as Gtk.CellRendererText;

            Transaction transaction;
            view_store.@get (iter, Column.TRANSACTION, out transaction, -1);

            cr.visible = transaction != null && transaction.date.compare (now) == 1;
        }

        private Gtk.TreeIter add_empty_row (Gtk.TreeIter? parent = null) {
            // add empty insert row

            var transaction = new Transaction ();
            transaction.amount = 0d;
            transaction.direction = Transaction.Direction.OUTGOING;
            transaction.date = new DateTime.now_local ();

            Gtk.TreeIter insert_iter;
            transactions_store.append (out insert_iter, parent);

            transactions_store.@set (insert_iter,
                Column.DATE, "",
                Column.MERCHANT, "",
                Column.MEMO, "",
                Column.OUTFLOW, "",
                Column.INFLOW, "",
                Column.ID, null,
                Column.TRANSACTION, transaction,
                Column.CATEGORY, "", -1);

            return insert_iter;
        }

        private void connect_signals () {

            // notify when a transaction changed
            transactions_store.row_changed.connect ((path, iter) => {
                transaction_edited (path, iter);
            });

            FilterView.get_default ().date_filter_changed.connect ( () => {

                var filter_view = FilterView.get_default ();

                filter_from = filter_view.from;
                filter_to = filter_view.to;

                add_transactions ();
            });

            treeview.row_activated.connect ( (path, column) => {
                treeview.scroll_to_cell (path, column, false, 1.0f, 1.0f);
            });

            // right-click menu
            treeview.button_press_event.connect ( (button_event) => {

                if (button_event.button == 3) {
                    // get targeted line
                    Gtk.TreePath target_path;
                    Gtk.TreeViewColumn target_column;
                    int target_x;
                    int target_y;

                    if (treeview.get_path_at_pos ((int) button_event.x, (int) button_event.y, out target_path, out target_column, out target_x, out target_y)) {

                        var selection = treeview.get_selection ();

                        selection.unselect_all ();
                        selection.select_path (target_path);

                        right_click_menu.popup (null, null, null, button_event.button, button_event.get_time ());
                    }

                    return false;
                }

                return false;
            });

            // remove transaction on delete key
            treeview.key_press_event.connect ( (event) => {
                if (event.keyval == Gdk.Key.Delete) {

                    if (current_add_transaction_action != AddTransactionAction.EDITING) {
                        // DEL key pressed! delete transaction
                        popup_menu_remove_activated ();
                    }
                }

                return false;
            });

            right_click_menu_item_remove.activate.connect (popup_menu_remove_activated);
            right_click_menu_item_split.activate.connect (popup_menu_split_activated);

            notify["transactions"].connect ( () => {
                if (transactions != null) {
                    add_transactions ();
                }
                else {
                    clear ();
                }
            });
        }

        private void popup_menu_remove_activated () {

            Gtk.TreeIter iter;
            if (!treeview.get_selection ().get_selected (null, out iter)) {
                return;
            }

            Transaction transaction;
            view_store.@get (iter, Column.TRANSACTION, out transaction, -1);

            try {
                AccountManager.get_default ().remove_transaction (ref transaction);

                Gtk.TreeIter child_iter;
                view_store.convert_iter_to_child_iter (out child_iter, iter);
                transactions_store.remove (ref child_iter);

                Envelope.App.toast (_("Transaction removed"));
            }
            catch (ServiceError err) {
                error ("error deleting transaction (%s)".printf (err.message));
            }
        }

        private void popup_menu_split_activated () {
            debug ("popup menu split activated");
        }

        private void save_transaction () {
            // save transaction
            string t_date;
            string t_label;
            string t_description;
            string t_in_amount;
            string t_out_amount;
            string t_category;

            Gtk.TreeIter view_iter;
            if (view_store.convert_child_iter_to_iter (out view_iter, current_editing_iter)) {

                view_store.@get (view_iter, Column.DATE, out t_date,
                    Column.MERCHANT, out t_label,
                    Column.MEMO, out t_description,
                    Column.INFLOW, out t_in_amount,
                    Column.OUTFLOW, out t_out_amount,
                    Column.CATEGORY, out t_category, -1);

                // amount
                double amount = 0d;

                try {
                    if (t_in_amount != "") {
                        amount = Envelope.Util.parse_currency (t_in_amount);
                    }
                    else if (t_out_amount != "") {
                        amount = - Envelope.Util.parse_currency (t_out_amount);
                    }
                }
                catch (Envelope.Util.ParseError err) {
                    error ("could not parse transaction amount (%s)".printf (err.message));
                }

                debug ("parsed amount: %f", amount);

                // date
                uint year, month, day;
                crdp.calendar.get_date (out year, out month, out day);

                var date = new DateTime.local ((int) year, (int) month + 1, (int) day, 0, 0, 0);

                // category
                Category? category = CategoryStore.get_default ().get_category_by_name (t_category);

                debug ("found category %d in store", category != null ? category.@id : -1);

                try {
                    var acct_ref = Sidebar.get_default ().selected_account;
                    AccountManager.get_default ().record_transaction (ref acct_ref, date, t_label, t_description, amount, category,  null);
                } catch (ServiceError err) {
                    error (err.message);
                }
            }
        }

        private void transaction_edited (Gtk.TreePath path, Gtk.TreeIter iter) {

            if (!populating_from_list) {

                Transaction transaction;

                string date;
                string label;
                string description;
                string in_amount;
                string out_amount;
                string category;

                transactions_store.@get (iter,
                    Column.DATE, out date,
                    Column.MERCHANT, out label,
                    Column.OUTFLOW, out out_amount,
                    Column.INFLOW, out in_amount,
                    Column.MEMO, out description,
                    Column.TRANSACTION, out transaction,
                    Column.CATEGORY, out category, -1);

                if (transaction != null) {

                    transaction.label = label;
                    transaction.description = description;

                    double amount = 0d;

                    if (in_amount != "") {
                        amount = double.parse (in_amount);
                        transaction.direction = Transaction.Direction.INCOMING;
                    }
                    else if (out_amount != "") {
                        amount = double.parse (out_amount);
                        transaction.direction = Transaction.Direction.OUTGOING;
                    }

                    transaction.amount = amount;

                    // TODO date

                    // TODO save
                }
            }
        }
    }
}
