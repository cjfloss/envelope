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

    public class TransactionView : Gtk.Box {

        private static const string CELL_COLOR_INCOMING = "green";
        private static const string CELL_COLOR_OUTGOING = "red";

        private Gtk.TreeView treeview;
        private Gtk.Label account_label;
        private Gtk.ScrolledWindow grid_scroll;

        // filter widgets
        private Gtk.RadioButton btn_this_month;
        private Gtk.RadioButton btn_last_month;
        private Gtk.RadioButton btn_future;
        private Gtk.RadioButton btn_manual;
        private Granite.Widgets.DatePicker from_date;
        private Granite.Widgets.DatePicker to_date;

        private Gtk.TreeStore transactions_store;

        public Account account { get; set; }

        public TransactionView () {

            Object (orientation: Gtk.Orientation.VERTICAL);

            build_ui ();
        }

        public TransactionView.with_account (Account account) {
            this ();
            this.account = account;
        }

        private void add_transactions (Gee.ArrayList<Transaction> transactions) {

            debug ("adding %d transactions".printf (transactions.size));

            var transaction_iter = transactions.iterator ();

            while (transaction_iter.next ()) {
                Transaction trans = transaction_iter.get();
                add_transaction (trans);
            }
        }

        private void add_transaction (Transaction transaction) {

            debug ("adding transaction %d in tree view".printf (transaction.id));

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

                debug ("transaction %d has parent %d".printf (transaction.@id, parent_transaction.@id));

                get_transaction_iter (parent_transaction, out parent_iter);
            }

            transactions_store.append (out iter, parent_iter);

            transactions_store.@set (iter,
                0, transaction.date.format("%x"),
                1, transaction.label,
                2, out_amount,
                3, in_amount,
                4, transaction.description,
                5, transaction.@id);

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
            update_view ();
        }

        public void clear () {
            transactions_store.clear ();
        }

        private void update_view () {
            treeview.columns_autosize ();
        }

        private void label_changed (string path, Gtk.TreeIter iter_new) {
            Gtk.TreeIter iter_val;
            Value val;

            transactions_store.get_value (iter_new, 1, out val);
            transactions_store.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
            transactions_store.set_value (iter_val, 1, val);

            // TODO update transaction object

            // TODO update database

            // TODO recalculate budget stats
        }

        public void load_account (Account account) {

            debug ("account changed");

            clear();

            if (account != null) {

                var transactions = account.transactions;

                if (transactions != null && transactions.size > 0) {
                    add_transactions (transactions);
                }
                else {
                    // TODO show nice "No transactions" message instead of grid view
                }
            }

            update_view ();
        }

        private void account_changed () {
            load_account (account);
        }

        private void build_ui () {

            debug ("building transaction view ui");

            width_request = 400;

            build_filter_ui ();
            build_transaction_grid_ui ();

            show_all ();
        }

        private void build_filter_ui () {

            debug ("building filter ui");

            // filters
            var filter_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            filter_box.border_width = 10;

            add (filter_box);

            // import button
            var import_button = new Gtk.Button.with_label (_("Import\u2026"));
            filter_box.pack_start (import_button, false, false);

            // this month
            btn_this_month = new Gtk.RadioButton (null);
            btn_this_month.label = _("This month");
            filter_box.add (btn_this_month);

            // last month
            btn_last_month = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Last month"));
            filter_box.add (btn_last_month);

            // future
            btn_future = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Future"));
            filter_box.add (btn_future);

            // manual dates
            btn_manual = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Pick dates:"));
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

            debug ("building tree ui");

            grid_scroll = new Gtk.ScrolledWindow (null, null);

            grid_scroll.vexpand = true;
            grid_scroll.vexpand_set = true;

            add (grid_scroll);

            treeview = new Gtk.TreeView ();

            grid_scroll.add (treeview);

            treeview.activate_on_single_click = true;
            treeview.reorderable = true;
            treeview.headers_clickable = true;
            treeview.show_expanders = true;
            treeview.rules_hint = true;
            treeview.set_search_column (1);
            treeview.show_all ();

            transactions_store = new Gtk.TreeStore(6,
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (int));

            treeview.set_model (transactions_store);

            // normal cell renderer
            Gtk.CellRendererText renderer = new Gtk.CellRendererText();
            renderer.editable = true;

            // label cell renderer
            Gtk.CellRendererCombo renderer_label = new Gtk.CellRendererCombo();
            renderer_label.editable = true;
            renderer_label.model = transactions_store;
            renderer_label.text_column = 1;

            renderer_label.changed.connect((path, iter_new) => {
                label_changed (path, iter_new);
            });

            // cell renderer for outgoing transactions
            Gtk.CellRendererText renderer_out = new Gtk.CellRendererText();
            renderer_out.editable = true;
            renderer_out.foreground = CELL_COLOR_OUTGOING;

            // cell renderer for incoming transactions
            Gtk.CellRendererText renderer_in = new Gtk.CellRendererText();
            renderer_in.editable = true;
            renderer_in.foreground = CELL_COLOR_INCOMING;

            // columns
            var date_column = new Gtk.TreeViewColumn ();
            date_column.set_title (_("Date"));
            date_column.max_width = -1;
            date_column.pack_start (renderer, true);
            date_column.resizable = true;
            date_column.set_attributes (renderer, "text", 0);
            treeview.append_column (date_column);

            var merchant_column = new Gtk.TreeViewColumn ();
            merchant_column.set_title (_("Merchant"));
            merchant_column.max_width = -1;
            merchant_column.pack_start (renderer, true);
            merchant_column.resizable = true;
            merchant_column.set_attributes (renderer, "text", 1);
            treeview.append_column (merchant_column);

            var memo_column = new Gtk.TreeViewColumn ();
            memo_column.set_title (_("Memo"));
            memo_column.max_width = -1;
            memo_column.pack_start (renderer, true);
            memo_column.resizable = true;
            memo_column.set_attributes (renderer, "text", 4);
            treeview.append_column (memo_column);

            var out_column = new Gtk.TreeViewColumn ();
            out_column.set_title (_("Outflow"));
            out_column.max_width = -1;
            out_column.pack_start (renderer_out, true);
            out_column.resizable = true;
            out_column.set_attributes (renderer_out, "text", 2);
            treeview.append_column (out_column);

            var in_column = new Gtk.TreeViewColumn ();
            in_column.set_title (_("Inflow"));
            in_column.max_width = -1;
            in_column.pack_start (renderer_in, true);
            in_column.resizable = true;
            in_column.set_attributes (renderer_in, "text", 3);
            treeview.append_column (in_column);

            /*
            treeview.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "resizable", true, null);
            treeview.insert_column_with_attributes (-1, _("Merchant"), renderer_label, "text", 1, "resizable", true, null);
            treeview.insert_column_with_attributes (-1, _("Memo"), renderer, "text", 4, "resizable", true, null);
            treeview.insert_column_with_attributes (-1, _("Outflow"), renderer_out, "text", 2, "resizable", true, null);
            treeview.insert_column_with_attributes (-1, _("Inflow"), renderer_in, "text", 3, "resizable", true, null);
            */

            grid_scroll.show_all ();
        }

        private void from_date_selected () {
            debug ("from date selected %s".printf (from_date.date.to_string ()));
        }

        private void to_date_selected () {
            debug ("to date selected %s".printf (to_date.date.to_string ()));
        }

    }
}
