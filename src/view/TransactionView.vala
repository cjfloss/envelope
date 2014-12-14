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

namespace Envelope.View {

    private static TransactionWelcomeScreen transaction_welcome_screen_instance = null;

    public class TransactionWelcomeScreen : Granite.Widgets.Welcome {

        public static new unowned TransactionWelcomeScreen get_default () {
            if (transaction_welcome_screen_instance == null) {
                transaction_welcome_screen_instance = new TransactionWelcomeScreen ();
            }

            return transaction_welcome_screen_instance;
        }

        private enum Action {
            ADD_TRANSACTION,
            IMPORT_TRANSACTIONS
        }

        public Account account { get; set; }

        public signal void add_transaction_selected (Account account);

        public TransactionWelcomeScreen () {
            base (_("Spend! Get paid!"), _("There are currently no transactions in this account"));
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            append ("add", _("Record a transaction"),
                _("Record a fresh new transaction for this account. Or, plan a future one!"));

            append ("document-import", _("Import transactions"),
                _("Import from a QIF file obtained from another application"));
        }

        private void connect_signals () {
            activated.connect (item_activated);
        }

        private void item_activated (int index ) {
            switch (index) {

                case Action.ADD_TRANSACTION:
                    add_transaction_selected (account);
                    break;

                case Action.IMPORT_TRANSACTIONS:
                    break;

                default:
                    assert_not_reached ();
            }
        }
    }

    private static TransactionView transaction_view_instance = null;

    public class TransactionView : Gtk.Box {

        private enum InfoBarResponse {
            OK
        }

        private enum DateFilter {
            THIS_MONTH,
            LAST_MONTH,
            MANUAL
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

        private static const int COLUMN_COUNT = 8;

        public static new unowned TransactionView get_default () {
            if (transaction_view_instance == null) {
                transaction_view_instance = new TransactionView ();
            }

            return transaction_view_instance;
        }

        private static const string CELL_COLOR_INCOMING = "green";
        private static const string CELL_COLOR_OUTGOING = "red";
        private static string CELL_DATE_FORMAT = Granite.DateTime.get_default_date_format (false, true, true);

        private Gtk.TreeView treeview;
        private Gtk.Box filter_box;
        private Gtk.ScrolledWindow grid_scroll;
        private Gtk.Box scroll_box;

        // filter widgets
        private Gtk.RadioButton btn_this_month;
        private Gtk.RadioButton btn_last_month;
        private Gtk.RadioButton btn_future;
        private Gtk.RadioButton btn_manual;
        private Granite.Widgets.DatePicker from_date;
        private Granite.Widgets.DatePicker to_date;
        private Gtk.Button btn_add_transaction;

        private Gtk.TreeStore transactions_store;
        private Gtk.ListStore merchant_store;

        private DateFilter date_filter = DateFilter.THIS_MONTH;

        public Account account { get; set; }

        private bool populating_from_list = false;

        public TransactionView () {

            Object (orientation: Gtk.Orientation.VERTICAL);

            build_ui ();
            transaction_view_instance = this;
        }

        public TransactionView.with_account (Account account) {
            this ();
            this.account = account;
            load_account (account);
        }

        private void add_transactions (Gee.ArrayList<Transaction> transactions) {

            debug ("adding %d transactions".printf (transactions.size));

            populating_from_list = true;

            // HUGE TODO: Use Gee.Traversable.filter
            var transaction_iter = transactions.iterator ();

            while (transaction_iter.next ()) {
                add_transaction (transaction_iter.get());
            }

            populating_from_list = false;
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

            transactions_store.append (out iter, parent_iter);

            transactions_store.@set (iter,
                Column.DATE, transaction.date.format (CELL_DATE_FORMAT),
                Column.MERCHANT, transaction.label,
                Column.OUTFLOW, out_amount,
                Column.INFLOW, in_amount,
                Column.MEMO, transaction.description,
                Column.ID, transaction.@id,
                Column.TRANSACTION, transaction,
                Column.CATEGORY, "", -1);

            update_view ();
        }

        private void get_transaction_iter (Transaction transaction, out Gtk.TreeIter? iter) {

            debug ("looking for tree iterator matching parent transaction %d".printf (transaction.@id));

            Gtk.TreeIter? found_iter = null;
            int id = transaction.@id;

            transactions_store.@foreach ((model, path, fe_iter) => {

                int val_id;

                model.@get (fe_iter, 5, out val_id, -1);

                if (val_id == id) {
                    found_iter = fe_iter;
                    return true;
                }

                return false;
            });

            iter = found_iter;
        }

        public void remove_transaction (Transaction transaction) {
            // TODO
            update_view ();
        }

        public void clear () {
            debug ("clear");
            transactions_store.clear ();
        }

        private void update_view () {
            treeview.show_all ();
            //treeview.columns_autosize ();
        }

        public void load_account (Account acct) {

            debug ("account changed");

            clear();

            Gee.ArrayList<Transaction>? transactions = null;

            if (acct != null) {

                transactions = acct.transactions;

                if (transactions != null && transactions.size > 0) {
                    add_transactions (transactions);
                }
                else {
                    // TODO show nice "No transactions" message instead of grid view
                }
            }

            if (transactions.size > 1) {
                filter_box.show_all ();
            }
            else {
                filter_box.hide ();
            }

            grid_scroll.show_all ();
            scroll_box.show_all ();
            treeview.show_all ();

            account = acct;

            update_view ();
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
            filter_box.border_width = 10;

            add (filter_box);

            // import button
            var import_button = new Gtk.Button.with_label (_("Import\u2026"));
            filter_box.pack_start (import_button, false, false);

            // this month
            btn_this_month = new Gtk.RadioButton (null);
            btn_this_month.label = _("This month");
            btn_this_month.toggled.connect ( () => {
                if (btn_this_month.get_active ()) {
                    date_filter = DateFilter.THIS_MONTH;

                    debug ("account is %d".printf (account.@id));

                    load_account (account);
                }
            });
            filter_box.add (btn_this_month);

            // last month
            btn_last_month = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Last month"));
            btn_last_month.toggled.connect ( () => {
                if (btn_last_month.get_active ()) {
                    date_filter = DateFilter.LAST_MONTH;
                    load_account (account);
                }
            });
            filter_box.add (btn_last_month);

            // future
            btn_future = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Future"));
            filter_box.add (btn_future);

            // manual dates
            btn_manual = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Pick dates:"));
            btn_manual.toggled.connect ( () => {
                if (btn_manual.get_active ()) {
                    date_filter = DateFilter.MANUAL;
                    from_date.sensitive = true;
                    to_date.sensitive = true;
                }
                else {
                    from_date.sensitive = false;
                    to_date.sensitive = false;
                }
            });
            filter_box.add (btn_manual);

            from_date = new Granite.Widgets.DatePicker ();
            from_date.sensitive = false;
            var a_month_ago = new DateTime.now_local ();
            from_date.date = a_month_ago.add_months (-1);

            // we need to be notified of date changes
            from_date.notify["date"].connect (from_date_selected);
            filter_box.add (from_date);

            to_date = new Granite.Widgets.DatePicker ();
            to_date.sensitive = false;
            to_date.date = new DateTime.now_local ();

            // we need to be notified of date changes
            to_date.notify["date"].connect (to_date_selected);
            filter_box.add (to_date);

            filter_box.show_all ();
        }

        private void build_transaction_grid_ui () {

            debug ("building transaction grid ui");

            grid_scroll = new Gtk.ScrolledWindow (null, null);

            grid_scroll.vexpand = true;
            grid_scroll.vexpand_set = true;

            add (grid_scroll);

            scroll_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            grid_scroll.add (scroll_box);
            scroll_box.show_all ();

            treeview = new Gtk.TreeView ();

            scroll_box.pack_start (treeview, false, false);

            btn_add_transaction = new Gtk.Button.with_label (_("Add transaction"));
            btn_add_transaction.show_all ();
            btn_add_transaction.expand = false;
            btn_add_transaction.clicked.connect (() => {
                add_empty_row ();
            });

            var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.set_layout (Gtk.ButtonBoxStyle.START);
            button_box.add (btn_add_transaction);
            button_box.set_spacing (10);
            button_box.border_width = 10;
            scroll_box.add (button_box);

            treeview.activate_on_single_click = true;
            treeview.reorderable = true;
            treeview.headers_clickable = true;
            treeview.show_expanders = true;
            treeview.rules_hint = true;
            treeview.set_search_column (1);
            treeview.show_all ();

            transactions_store = new Gtk.TreeStore(COLUMN_COUNT,
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (int),
                typeof (Transaction),
                typeof (string)); // todo change to category type

            merchant_store = new Gtk.ListStore (2,
                typeof (string), // merchant
                typeof (int));   // occurences

            // load merchants
            var merchants = DatabaseManager.get_default ().get_merchants ();

            foreach (Merchant m in merchants) {
                Gtk.TreeIter iter;
                merchant_store.append (out iter);
                merchant_store.@set (iter, 0, m.label, -1);
                merchant_store.@set (iter, 1, m.occurences, -1);
            }

            // notify when a transaction changed
            transactions_store.row_changed.connect ((path, iter) => {

                transaction_edited (path, iter);

                // add new empty row if iter is last
                //if (!transactions_store.iter_next (ref iter)) {
                    // iter has no next, append
                if (!populating_from_list) {
                    //add_empty_row ();
                }
                //}
            });

            treeview.set_model (transactions_store);

            // memo cell renderer
            Gtk.CellRendererText renderer_memo = new Gtk.CellRendererText();
            renderer_memo.editable = true;
            renderer_memo.edited.connect ((path, text) => {
                Gtk.TreeIter iter;

                if (transactions_store.get_iter_from_string (out iter, path)) {
                    debug ("edited: setting memo in store");
                    transactions_store.@set (iter, Column.MEMO, text, -1);
                }
            });

            // label cell renderer
            var renderer_label = new CellRendererTextCompletion ();
            renderer_label.store = merchant_store;
            renderer_label.text_column = 0;
            renderer_label.editable = true;
            renderer_label.edited.connect ((path, text) =>  {
                Gtk.TreeIter iter;

                if (transactions_store.get_iter_from_string (out iter, path)) {
                    debug ("edited: setting merchant in store");
                    transactions_store.@set (iter, Column.MERCHANT, text, -1);
                }
            });

            // cell renderer for outgoing transactions
            Gtk.CellRendererText renderer_out = new Gtk.CellRendererText();
            renderer_out.editable = true;
            renderer_out.foreground = CELL_COLOR_OUTGOING;
            renderer_out.xalign = 1.0f;
            renderer_out.edited.connect ((path, text) =>  {
                Gtk.TreeIter iter;

                if (transactions_store.get_iter_from_string (out iter, path)) {
                    debug ("edited: setting outgoing amount in store");
                    transactions_store.@set (iter, Column.OUTFLOW, Envelope.Util.format_currency (double.parse (text)), -1);
                }
            });

            // cell renderer for incoming transactions
            Gtk.CellRendererText renderer_in = new Gtk.CellRendererText();
            renderer_in.editable = true;
            renderer_in.foreground = CELL_COLOR_INCOMING;
            renderer_in.xalign = 1.0f;
            renderer_in.edited.connect ((path, text) =>  {
                Gtk.TreeIter iter;

                if (transactions_store.get_iter_from_string (out iter, path)) {
                    debug ("edited: setting incoming amount in store");
                    transactions_store.@set (iter, Column.INFLOW, Envelope.Util.format_currency (double.parse (text)), -1);
                }
            });

            var crdp = new CellRendererDatePicker (treeview);
            crdp.editable = true;
            crdp.editable_set = true;
            crdp.edited.connect ((path, text) => {

                if (crdp.date_selected) {
                    Gtk.TreeIter iter;

                    if (transactions_store.get_iter_from_string (out iter, path)) {
                        debug ("edited: setting date in store");
                        transactions_store.@set (iter, Column.DATE, text, -1);
                    }
                }
            });

            // columns
            var date_column = new Gtk.TreeViewColumn ();
            date_column.set_title (_("Date"));
            date_column.max_width = -1;
            date_column.pack_start (crdp, true);
            date_column.resizable = true;
            date_column.set_attributes (crdp, "text", Column.DATE);
            treeview.append_column (date_column);

            var merchant_column = new Gtk.TreeViewColumn ();
            merchant_column.set_title (_("Merchant"));
            merchant_column.max_width = -1;
            merchant_column.pack_start (renderer_label, true);
            merchant_column.resizable = true;
            merchant_column.set_attributes (renderer_label, "text", Column.MERCHANT);
            treeview.append_column (merchant_column);

            var out_column = new Gtk.TreeViewColumn ();
            out_column.set_title (_("Outflow"));
            out_column.max_width = -1;
            out_column.pack_start (renderer_out, true);
            out_column.resizable = true;
            out_column.set_attributes (renderer_out, "text", Column.OUTFLOW);
            treeview.append_column (out_column);

            var in_column = new Gtk.TreeViewColumn ();
            in_column.set_title (_("Inflow"));
            in_column.max_width = -1;
            in_column.pack_start (renderer_in, true);
            in_column.resizable = true;
            in_column.set_attributes (renderer_in, "text", Column.INFLOW);
            treeview.append_column (in_column);

            var memo_column = new Gtk.TreeViewColumn ();
            memo_column.set_title (_("Memo"));
            memo_column.max_width = -1;
            memo_column.pack_start (renderer_memo, true);
            memo_column.resizable = true;
            memo_column.set_attributes (renderer_memo, "text", Column.MEMO);
            treeview.append_column (memo_column);

            grid_scroll.show_all ();
            treeview.show_all ();
        }

        private void add_empty_row (Gtk.TreeIter? parent = null) {
            // add empty insert row
            Gtk.TreeIter insert_iter;
            transactions_store.append (out insert_iter, parent);
            transactions_store.@set (insert_iter,
                Column.DATE, "",
                Column.MERCHANT, "",
                Column.MEMO, "",
                Column.OUTFLOW, "",
                Column.INFLOW, "",
                Column.ID, null,
                Column.TRANSACTION, null,
                Column.CATEGORY, "", -1);
        }

        private void from_date_selected () {
            debug ("from date selected %s".printf (from_date.date.to_string ()));
        }

        private void to_date_selected () {
            debug ("to date selected %s".printf (to_date.date.to_string ()));
        }

        private void transaction_edited (Gtk.TreePath path, Gtk.TreeIter iter) {
            if (!populating_from_list) {

                Transaction transaction;
                string date;
                string label;
                string description;
                string in_amount;
                string out_amount;

                transactions_store.@get (iter,
                    Column.DATE, out date,
                    Column.MERCHANT, out label,
                    Column.OUTFLOW, out out_amount,
                    Column.INFLOW, out in_amount,
                    Column.MEMO, out description,
                    Column.TRANSACTION, out transaction, -1);

                if (transaction != null) {

                    transaction.label = label;
                    transaction.description = description;

                    double? amount = null;

                    if (in_amount != "") {
                        amount = double.parse (in_amount);
                        transaction.direction = Transaction.Direction.INCOMING;
                    }
                    else if (out_amount != "") {
                        amount = double.parse (out_amount);
                        transaction.direction = Transaction.Direction.OUTGOING;
                    }
                    else {
                        debug ("warning! no amount set!!!");
                    }

                    transaction.amount = amount;

                    // TODO date
                }
            }
        }
    }
}
