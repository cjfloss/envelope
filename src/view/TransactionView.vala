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
            CATEGORY,
            COLOR
        }

        private enum AddTransactionAction {
            NONE,
            EDITING
        }

        private static const int COLUMN_COUNT = 9;
        private static const string CELL_COLOR_INCOMING = "#4e9a06";
        private static const string CELL_COLOR_OUTGOING = "#A62626";
        private static string CELL_DATE_FORMAT = "%x"; // preferred format according to locale

        private Gtk.TreeView treeview;
        private Gtk.Box filter_box;
        private Gtk.ScrolledWindow grid_scroll;

        private CellRendererDatePicker crdp;
        private Gtk.CellRendererText renderer_memo;

        private Gtk.Button btn_add_transaction;
        private Gtk.Button btn_add_transaction_cancel;
        private Gtk.ButtonBox button_box;
        private Gtk.InfoBar infobar;

        private Gtk.TreeStore transactions_store;
        private Gtk.TreeModelFilter view_store;
        private Gtk.TreeModelSort tree_model_sort;
        private Gtk.TreeIter current_editing_iter;

        private string future_transaction_text_color;

        private bool populating_from_list = false;

        private DateTime filter_from = null;
        private DateTime filter_to = null;

        private AddTransactionAction current_add_transaction_action = AddTransactionAction.NONE;

        private Gtk.Menu right_click_menu;
        private Gtk.MenuItem right_click_menu_item_split;
        private Gtk.MenuItem right_click_menu_item_remove;

        public string search_term { get; set; default = ""; }

        public Gee.List<Transaction> transactions { get; set; }

        public bool with_filter_view { get; set; default = true; }
        public bool with_add_transaction_view { get; set; default = true; }

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
                typeof (string),
                typeof (string));

            view_store = new Gtk.TreeModelFilter (transactions_store, null);
            view_store.set_visible_func (view_store_filter_func);

            build_ui ();
            connect_signals ();
            transaction_view_instance = this;
        }

        public void set_search_filter (string term) {

            debug ("set_search_filter (%s)", term);

            search_term = term.strip ().length > 0 ? term.strip ().up () : "";
            apply_filters ();
        }

        public void add_transaction (Transaction transaction) {
            var in_amount = "";
            var out_amount = "";
            var formatted_amount = Envelope.Util.String.format_currency (transaction.amount, false);

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

            var color = get_foreground_from_date (transaction.date);

            transactions_store.append (out iter, parent_iter);
            transactions_store.@set (iter,
                Column.DATE, transaction.date.format (CELL_DATE_FORMAT),
                Column.MERCHANT, transaction.label,
                Column.OUTFLOW, out_amount,
                Column.INFLOW, in_amount,
                Column.MEMO, transaction.description,
                Column.ID, transaction.@id,
                Column.TRANSACTION, transaction,
                Column.CATEGORY, category_name,
                Column.COLOR, color, -1);

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

            if (transaction == null || transaction.@id == null) {
                return true; //editing... always shown
            }

            if (search_term != "") {

                var label = transaction.label.up ();

                if (label.index_of (search_term) == -1) {

                    var desc = (transaction.description != null ? transaction.description : "").up ();

                    if (desc.index_of (search_term) == -1) {
                        return false;
                    }
                }
            }

            // no search, or transaction matches search, continue with dates
            var tdate = transaction.date;

            var is_after_start = filter_from != null ? tdate.compare (filter_from) >= 0 : true;
            var is_before_end = filter_to != null ? tdate.compare (filter_to) <= 0 : true;

            return is_after_start && is_before_end;
        }

        /**
         * Adds a list of transactions to the grid store
         */
        private void add_transactions () {

            populating_from_list = true;

            clear ();

            if (transactions != null) {

                foreach (Transaction transaction in transactions) {
                    add_transaction (transaction);
                }
            }

            populating_from_list = false;

            // check if we need to display the infobar
            Gtk.TreeIter iter_first;
            if (!view_store.get_iter_first (out iter_first)) {
                // we don't have children; display infobar
                infobar.show_all ();
            }
            else {
                infobar.hide ();
            }
        }

        private void get_transaction_iter (Transaction transaction, out Gtk.TreeIter? iter) {

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

            var filter_view = FilterView.get_default ();
            filter_view.filter_type = FilterView.FilterType.THIS_MONTH;
            filter_from = filter_view.from;
            filter_to = filter_view.to;

            filter_box.pack_start (filter_view);
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

            future_transaction_text_color = "#aaa";

            grid_scroll = new Gtk.ScrolledWindow (null, null);
            grid_scroll.vexpand = true;
            grid_scroll.vexpand_set = true;
            grid_scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

            add (grid_scroll);

            treeview = new Gtk.TreeView ();

            grid_scroll.add (treeview);
            grid_scroll.show_all ();

            btn_add_transaction = new Gtk.Button.with_label (_("Add transaction"));
            btn_add_transaction.show_all ();
            btn_add_transaction.expand = false;

            btn_add_transaction_cancel = new Gtk.Button.with_label (_("Cancel"));
            btn_add_transaction_cancel.expand = false;
            btn_add_transaction_cancel.visible = false;

            button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.layout_style = Gtk.ButtonBoxStyle.START;
            button_box.border_width = 5;
            button_box.spacing = 5;
            button_box.add (btn_add_transaction);
            button_box.add (btn_add_transaction_cancel);

            pack_end (button_box, false, false);

            button_box.show ();

            treeview.activate_on_single_click = false;
            treeview.reorderable = true;
            treeview.headers_clickable = true;
            treeview.show_expanders = false;
            treeview.rules_hint = true;
            treeview.enable_grid_lines = Gtk.TreeViewGridLines.HORIZONTAL;
            treeview.fixed_height_mode = true;

            tree_model_sort = new Gtk.TreeModelSort.with_model (view_store);
            tree_model_sort.set_sort_func (Column.INFLOW, treemodel_sort_amount);
            tree_model_sort.set_sort_func (Column.OUTFLOW, treemodel_sort_amount);
            tree_model_sort.set_sort_func (Column.DATE, treemodel_sort_date);

            treeview.set_model (tree_model_sort);
            treeview.set_search_column (1);
            treeview.show_all ();

            // memo cell renderer
            renderer_memo = new Gtk.CellRendererText();
            renderer_memo.editable = true;
            renderer_memo.ellipsize = Pango.EllipsizeMode.END;
            renderer_memo.ellipsize_set = true;
            renderer_memo.edited.connect ((path, text) => {

                Gtk.TreeIter iter;
                if (tree_model_sort.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    get_transaction_iter_from_sort_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.MEMO, text, -1);
                }
            });

            // label cell renderer
            var renderer_label = new CellRendererTextCompletion ();
            renderer_label.store = MerchantStore.get_default ();
            renderer_label.text_column = 0;
            renderer_label.editable = true;
            renderer_label.ellipsize = Pango.EllipsizeMode.END;
            renderer_label.ellipsize_set = true;
            renderer_label.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;
                if (tree_model_sort.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    get_transaction_iter_from_sort_iter (out store_iter, iter);

                    transactions_store.@set (store_iter, Column.MERCHANT, text, -1);
                }
            });

            // category cell renderer
            var renderer_category = new CellRendererCategoryPicker (treeview);
            renderer_category.store = CategoryStore.get_default ();
            renderer_category.text_column = CategoryStore.Column.LABEL;
            renderer_category.ellipsize = Pango.EllipsizeMode.END;
            renderer_category.ellipsize_set = true;
            renderer_category.edited.connect ((path, text) => {

                if (text.strip () == "") {
                    return;
                }

                Gtk.TreeIter iter;
                if (tree_model_sort.get_iter_from_string (out iter, path)) {

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
                    get_transaction_iter_from_sort_iter (out store_iter, iter);

                    string merchant;
                    transactions_store.@get (store_iter, Column.MERCHANT, out merchant, -1);

                    if (renderer_category.apply_to_all) {
                        try {
                            BudgetManager.get_default ().categorize_all_for_merchant (merchant, category);
                            transactions = AccountManager.get_default ().load_account_transactions (Sidebar.get_default ().selected_account);
                            add_transactions ();
                        }
                        catch (ServiceError err) {
                            error ("could not categorize all transactions (%s)", err.message);
                        }
                    }
                    else {
                        // update transaction object
                        Transaction transaction;
                        transactions_store.@get (store_iter, Column.TRANSACTION, out transaction, -1);
                        transaction.category = category;

                        transactions_store.@set (store_iter, Column.CATEGORY, category != null ? category.name : "", -1);
                    }
                }
            });

            // cell renderer for outgoing transactions
            Gtk.CellRendererText renderer_out = new Gtk.CellRendererText();
            renderer_out.editable = true;
            renderer_out.foreground = CELL_COLOR_OUTGOING;
            renderer_out.xalign = 1.0f;
            renderer_out.ellipsize = Pango.EllipsizeMode.END;
            renderer_out.ellipsize_set = true;
            renderer_out.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;
                if (tree_model_sort.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    get_transaction_iter_from_sort_iter (out store_iter, iter);

                    string? outflow;

                    if (text.strip () != "") {
                        try {
                            outflow = Envelope.Util.String.format_currency (Envelope.Util.String.parse_currency (text), false);
                        }
                        catch (Envelope.Util.String.ParseError err) {
                            outflow = "<error>";
                        }
                    }
                    else {
                        outflow = null;
                    }

                    transactions_store.@set (store_iter, Column.OUTFLOW, outflow, -1);
                }
            });

            // cell renderer for incoming transactions
            Gtk.CellRendererText renderer_in = new Gtk.CellRendererText();
            renderer_in.editable = true;
            renderer_in.foreground = CELL_COLOR_INCOMING;
            renderer_in.xalign = 1.0f;
            renderer_in.ellipsize = Pango.EllipsizeMode.END;
            renderer_in.ellipsize_set = true;
            renderer_in.edited.connect ((path, text) =>  {

                Gtk.TreeIter iter;
                if (tree_model_sort.get_iter_from_string (out iter, path)) {

                    Gtk.TreeIter store_iter;
                    get_transaction_iter_from_sort_iter (out store_iter, iter);

                    string? inflow;

                    if (text.strip () != "") {
                        try {
                            inflow = Envelope.Util.String.format_currency (Envelope.Util.String.parse_currency (text), false);
                        }
                        catch (Envelope.Util.String.ParseError err) {
                            inflow = "<error>";
                        }
                    }
                    else {
                        inflow = null;
                    }

                    transactions_store.@set (store_iter, Column.INFLOW, inflow, -1);
                }
            });

            crdp = new CellRendererDatePicker (treeview);
            crdp.xalign = 1.0f;
            crdp.ellipsize = Pango.EllipsizeMode.END;
            crdp.ellipsize_set = true;
            crdp.edited.connect ((path, text) => {

                if (crdp.date_selected) {

                    Gtk.TreeIter iter;
                    if (tree_model_sort.get_iter_from_string (out iter, path)) {

                        Gtk.TreeIter store_iter;
                        get_transaction_iter_from_sort_iter (out store_iter, iter);

                        transactions_store.@set (store_iter, Column.DATE, text, -1);
                    }
                }
            });

            // columns
            var date_column = new Gtk.TreeViewColumn ();
            date_column.set_title (_("Date"));
            date_column.max_width = -1;
            date_column.min_width = 80;
            date_column.pack_start (crdp, true);
            date_column.resizable = true;
            date_column.reorderable = true;
            date_column.sort_column_id = Column.DATE;
            date_column.set_cell_data_func (crdp, cell_renderer_color_function);
            date_column.set_attributes (crdp, "text", Column.DATE);
            date_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            treeview.append_column (date_column);

            var merchant_column = new Gtk.TreeViewColumn ();
            merchant_column.set_title (_("Merchant"));
            merchant_column.max_width = -1;
            merchant_column.min_width = 150;
            merchant_column.pack_start (renderer_label, true);
            merchant_column.resizable = true;
            merchant_column.reorderable = true;
            merchant_column.sort_column_id = Column.MERCHANT;
            merchant_column.set_attributes (renderer_label, "text", Column.MERCHANT);
            merchant_column.set_cell_data_func (renderer_label, cell_renderer_color_function);
            merchant_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            treeview.append_column (merchant_column);

            var category_column = new Gtk.TreeViewColumn ();
            category_column.set_title (_("Category"));
            category_column.max_width = -1;
            category_column.min_width = 100;
            category_column.pack_start (renderer_category, true);
            category_column.resizable = true;
            category_column.reorderable = true;
            category_column.sort_column_id = Column.CATEGORY;
            category_column.set_cell_data_func (renderer_category, cell_renderer_category_func);
            category_column.set_attributes (renderer_category, "text", Column.CATEGORY);
            category_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            treeview.append_column (category_column);

            var out_column = new Gtk.TreeViewColumn ();
            out_column.set_title (_("Outflow (%s)").printf (Envelope.Util.String.get_currency_symbol ()));
            out_column.max_width = -1;
            out_column.min_width = 80;
            out_column.pack_start (renderer_out, true);
            out_column.resizable = true;
            out_column.reorderable = true;
            out_column.sort_column_id = Column.OUTFLOW;
            out_column.set_attributes (renderer_out, "text", Column.OUTFLOW);
            out_column.set_cell_data_func (renderer_out, cell_renderer_color_outflow_function);
            out_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            treeview.append_column (out_column);

            var in_column = new Gtk.TreeViewColumn ();
            in_column.set_title (_("Inflow (%s)").printf (Envelope.Util.String.get_currency_symbol ()));
            in_column.max_width = -1;
            in_column.min_width = 80;
            in_column.pack_start (renderer_in, true);
            in_column.resizable = true;
            in_column.reorderable = true;
            in_column.sort_column_id = Column.INFLOW;
            in_column.set_attributes (renderer_in, "text", Column.INFLOW);
            in_column.set_cell_data_func (renderer_in, cell_renderer_color_inflow_function);
            in_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            treeview.append_column (in_column);

            var memo_column = new Gtk.TreeViewColumn ();
            memo_column.set_title (_("Memo"));
            memo_column.max_width = -1;
            memo_column.pack_start (renderer_memo, true);
            memo_column.resizable = true;
            memo_column.reorderable = true;
            memo_column.sort_column_id = Column.MEMO;
            memo_column.spacing = 10;
            memo_column.set_attributes (renderer_memo, "text", Column.MEMO);
            memo_column.set_cell_data_func (renderer_memo, cell_renderer_color_function);
            memo_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
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
        }

        private void cell_renderer_category_func (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            cell_renderer_color_function (layout, renderer, model, iter);

            CellRendererCategoryPicker cp = renderer as CellRendererCategoryPicker;

            string merchant;
            string category_name;
            model.@get (iter, Column.MERCHANT, out merchant, Column.CATEGORY, out category_name, -1);

            cp.merchant_name = merchant;
            cp.category_name = category_name;
        }

        private void cell_renderer_color_inflow_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
            set_cell_foreground_from_date (layout, renderer, model, iter, CELL_COLOR_INCOMING);
        }

        private void cell_renderer_color_outflow_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
            set_cell_foreground_from_date (layout, renderer, model, iter, CELL_COLOR_OUTGOING);
        }

        private void cell_renderer_color_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
            set_cell_foreground_from_date (layout, renderer, model, iter);
        }

        private void set_cell_foreground_from_date (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter, string? default_color = null) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;

            string? color;
            model.@get (iter, Column.COLOR, out color, -1);

            if (color != null) {
                crt.foreground = color;
                crt.foreground_set = true;
            }
            else if (default_color != null) {
                crt.foreground = default_color;
                crt.foreground_set = true;
            }
            else {
                crt.foreground_set = false;
            }
        }

        private int treemodel_sort_amount (Gtk.TreeModel model, Gtk.TreeIter iter1, Gtk.TreeIter iter2) {

            var sortable = treeview.model as Gtk.TreeModelSort;

            int column;
            Gtk.SortType type;
            sortable.get_sort_column_id (out column, out type);

            string? amount1;
            string? amount2;
            model.@get (iter1, column, out amount1, -1);
            model.@get (iter2, column, out amount2, -1);

            if ((amount1 == null && amount2 == null) || (amount1 == "" && amount2 == "")) {
                return 0;
            }

            if ((amount1 == null || amount1 == "") && (amount2 != null && amount2 != "")) {
                return -1;
            }

            if ((amount1 != null && amount1 != "") && (amount2 == null || amount2 == "")) {
                return 1;
            }

            try {
                double parsed1 = Envelope.Util.String.parse_currency (amount1);
                double parsed2 = Envelope.Util.String.parse_currency (amount2);

                if (parsed1 > parsed2) { return 1; }
                if (parsed1 < parsed2) { return -1; }
            }
            catch (Envelope.Util.String.ParseError err) {
                return 0;
            }

            return 0;
        }

        private int treemodel_sort_date (Gtk.TreeModel model, Gtk.TreeIter iter1, Gtk.TreeIter iter2) {

            var sortable = treeview.model as Gtk.TreeModelSort;

            int column;
            Gtk.SortType type;
            sortable.get_sort_column_id (out column, out type);

            string? date1;
            string? date2;
            model.@get (iter1, column, out date1, -1);
            model.@get (iter2, column, out date2, -1);

            if ((date1 == null && date2 == null) || (date1 == "" && date2 == "")) {
                return 0;
            }

            if ((date1 == null || date1 == "") && (date2 != null && date2 != "")) {
                return -1;
            }

            if ((date1 != null && date1 != "") && (date2 == null || date2 == "")) {
                return 1;
            }

            Date dt1 = Date ();
            dt1.clear ();

            Date dt2 = Date ();
            dt2.clear ();

            dt1.set_parse (date1);
            dt2.set_parse (date2);

            var valid1 = dt1.valid ();
            var valid2 = dt2.valid ();

            if (!valid1 && !valid2) {
                return 0;
            }

            if (valid1 && !valid2) {
                return 1;
            }

            if (!valid1 && valid2) {
                return -1;
            }

            return dt1.compare (dt2);
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

            btn_add_transaction_cancel.clicked.connect (btn_add_transactions_cancel_clicked);
            btn_add_transaction.clicked.connect (btn_add_transactions_clicked);

            // notify when a transaction changed
            transactions_store.row_changed.connect ((path, iter) => {
                transaction_edited (path, iter);
            });

            FilterView.get_default ().date_filter_changed.connect ( () => {

                var filter_view = FilterView.get_default ();

                filter_from = filter_view.from;
                filter_to = filter_view.to;

                view_store.refilter ();
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

            notify["with-filter-view"].connect ( () => {

                debug ("with_filter_view changed (%s)", with_filter_view ? "true" : "false");

                if (!with_filter_view) {
                    FilterView.get_default ().filter_type = FilterView.FilterType.THIS_MONTH;
                    filter_box.hide ();
                }
                else {
                    filter_box.show ();
                }
            });

            notify["with-add-transaction-view"].connect ( () => {

                debug ("with_add_transaction_view changed (%s)", with_add_transaction_view ? "true" : "false");

                if (!with_add_transaction_view) {
                    button_box.hide ();
                }
                else {
                    button_box.show ();
                }
            });
        }

        public void btn_add_transactions_clicked () {
            switch (current_add_transaction_action) {
                case AddTransactionAction.NONE:
                    // add a row
                    current_editing_iter = add_empty_row ();

                    // convert to child model iter
                    Gtk.TreeIter child_iter;
                    view_store.convert_child_iter_to_iter (out child_iter, current_editing_iter);

                    Gtk.TreePath path = view_store.get_path (child_iter);
                    treeview.scroll_to_cell (path, treeview.get_column (0), true, 0, 0);

                    btn_add_transaction.get_style_context ().add_class("suggested-action");
                    btn_add_transaction.label = _("Apply");

                    current_add_transaction_action = AddTransactionAction.EDITING;

                    btn_add_transaction_cancel.show ();

                    // focus
                    treeview.get_selection ().select_path (path);

                    break;

                case AddTransactionAction.EDITING:
                    save_transaction ();

                    // restore previous state
                    current_add_transaction_action = AddTransactionAction.NONE;
                    btn_add_transaction.get_style_context ().remove_class("suggested-action");
                    btn_add_transaction.label = _("Add transaction");

                    btn_add_transaction_cancel.hide ();

                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void btn_add_transactions_cancel_clicked () {
            switch (current_add_transaction_action) {
                case AddTransactionAction.EDITING:
                    current_add_transaction_action = AddTransactionAction.NONE;

                    transactions_store.remove (ref current_editing_iter);

                    btn_add_transaction.get_style_context ().remove_class("suggested-action");
                    btn_add_transaction.label = _("Add transaction");

                    btn_add_transaction_cancel.hide ();

                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void popup_menu_remove_activated () {

            Gtk.TreeIter iter;
            if (!treeview.get_selection ().get_selected (null, out iter)) {
                return;
            }

            Transaction transaction;
            treeview.model.@get (iter, Column.TRANSACTION, out transaction, -1);

            debug ("removing transaction with date %s", transaction.date.to_string ());

            try {
                AccountManager.get_default ().remove_transaction (ref transaction);

                Gtk.TreeIter transaction_iter;
                get_transaction_iter_from_sort_iter (out transaction_iter, iter);

                transactions_store.remove (ref transaction_iter);

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
                        amount = Envelope.Util.String.parse_currency (t_in_amount);
                    }
                    else if (t_out_amount != "") {
                        amount = - Envelope.Util.String.parse_currency (t_out_amount);
                    }
                }
                catch (Envelope.Util.String.ParseError err) {
                    error ("could not parse transaction amount (%s)".printf (err.message));
                }

                // date
                uint year, month, day;
                crdp.calendar.get_date (out year, out month, out day);

                var date = new DateTime.local ((int) year, (int) month + 1, (int) day, 0, 0, 0);

                // category
                Category? category = CategoryStore.get_default ().get_category_by_name (t_category);

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
                string category_name;

                transactions_store.@get (iter,
                    Column.DATE, out date,
                    Column.MERCHANT, out label,
                    Column.OUTFLOW, out out_amount,
                    Column.INFLOW, out in_amount,
                    Column.MEMO, out description,
                    Column.TRANSACTION, out transaction,
                    Column.CATEGORY, out category_name, -1);

                if (transaction != null && transaction.@id != null) {

                    transaction.label = label;
                    transaction.description = description;

                    try {
                        if (in_amount != "") {
                            transaction.amount = Envelope.Util.String.parse_currency (in_amount);
                            transaction.direction = Transaction.Direction.INCOMING;
                        }
                        else if (out_amount != "") {
                            transaction.amount = Envelope.Util.String.parse_currency (out_amount);
                            transaction.direction = Transaction.Direction.OUTGOING;
                        }
                    }
                    catch (Envelope.Util.String.ParseError err) {
                        error ("could not parse transaction amount (%s)".printf (err.message));
                    }

                    // date
                    var parse_date = Date ();
                    parse_date.clear ();
                    parse_date.set_parse (date);

                    if (!parse_date.valid ()) {
                        warning ("could not parse date %s", date);
                        return;
                    }

                    transaction.date = new DateTime.local (parse_date.get_year (),
                        parse_date.get_month (),
                        parse_date.get_day (), 0, 0, 0);

                    // category
                    transaction.category = CategoryStore.get_default ().get_category_by_name (category_name);

                    // update
                    try {
                        AccountManager.get_default ().update_transaction (transaction);
                    }
                    catch (ServiceError err) {
                        error ("could not update transaction (%s)", err.message);
                    }
                }
            }
        }

        private string? get_foreground_from_date (DateTime? date, string? default_color = null) {

            if (date != null) {
                var now = new DateTime.now_local ();

                if (now.compare (date) == -1) {
                    return future_transaction_text_color;
                }
                else {
                    if (default_color != null) {
                        return default_color;
                    }
                    else {
                        return null;
                    }
                }
            }

            return null;
        }

        /**
         * Convert an TreeIter from the TreeModelSort to an iter to the transactions store
         *
         * @param transaction_iter the Gtk.TreeIter to initialize
         * @param sort_iter the Gtk.TreeIter to convert
         */
        private void get_transaction_iter_from_sort_iter (out Gtk.TreeIter transaction_iter, Gtk.TreeIter sort_iter) {
            Gtk.TreeIter view_iter;
            (treeview.model as Gtk.TreeModelSort).convert_iter_to_child_iter (out view_iter, sort_iter);
            view_store.convert_iter_to_child_iter (out transaction_iter, view_iter);
        }
    }
}
