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
                    var view = TransactionView.get_default();
                    view.account = account;
                    view.show_import_dialog ();
                    break;

                default:
                    assert_not_reached ();
            }
        }
    }

    private static TransactionView transaction_view_instance = null;

    public class TransactionView : Gtk.Box {

        public static new unowned TransactionView get_default () {
            if (transaction_view_instance == null) {
                transaction_view_instance = new TransactionView ();
            }

            return transaction_view_instance;
        }

        private enum InfoBarResponse {
            CLEAR
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
        private static const string CELL_COLOR_INCOMING = "#4e9a06";
        private static const string CELL_COLOR_OUTGOING = "#A62626";
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
        private Gtk.InfoBar infobar;

        private Gtk.TreeStore transactions_store;

        private bool populating_from_list = false;

        private DateTime now = new DateTime.now_local ();

        private DateFilter date_filter = DateFilter.THIS_MONTH;

        public Gtk.ListStore merchant_store { get; set; }
        public Account account { get; set; }
        public string search_term { get; set; }

        public TransactionView () {

            Object (orientation: Gtk.Orientation.VERTICAL);

            build_ui ();
            connect_signals ();
            transaction_view_instance = this;
        }

        public TransactionView.with_account (Account account) {
            this ();
            this.account = account;
            load_account (account);
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

        public void remove_transaction (Transaction transaction) {
            // TODO
            update_view ();
        }

        public void clear () {
            debug ("clear");
            transactions_store.clear ();
        }

        public void load_account (Account acct) {

            debug ("account changed");

            clear();

            now = new DateTime.now_local ();

            Gee.ArrayList<Transaction>? transactions = null;

            if (acct != null) {

                transactions = acct.transactions;

                if (transactions != null && transactions.size > 0) {
                    add_transactions (transactions);
                }
            }

            account = acct;

            update_view ();
        }

        public void show_import_dialog () {
            // show open file dialog
            var chooser = new Gtk.FileChooserDialog (_("Import a QIF file"), Envelope.App.get_default ().main_window,
            Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);

            debug ("setting file chooser to this path: %s".printf (Granite.Services.Paths.home_folder.get_path ()));

            chooser.select_multiple = false;
            chooser.create_folders = false;
            chooser.set_current_folder_file (Granite.Services.Paths.home_folder);

            var filter = new Gtk.FileFilter ();
            chooser.set_filter (filter);
            filter.add_pattern ("*.qif");

            var response = chooser.run ();

            switch (response) {
                case Gtk.ResponseType.ACCEPT:
                case Gtk.ResponseType.OK:

                    chooser.close ();

                    try {

                        var local_account = account;

                        AccountManager.get_default ().import_transactions_from_file (ref local_account, chooser.get_file ());

                        //load_account (account);
                        Sidebar.get_default ().select_account (account);

                    } catch (ServiceError err) {
                        error (err.message);
                    } catch (ImporterError err) {
                        assert (!(err is ImporterError.UNSUPPORTED));
                        error (err.message);
                    }

                    break;

                case Gtk.ResponseType.CANCEL:
                case Gtk.ResponseType.CLOSE:
                    chooser.close ();
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void get_filter_dates (out DateTime this_month, out DateTime last_month, out DateTime future, out DateTime from, out DateTime to) {
            //var now = new DateTime.now_local ();

            this_month = new DateTime.local (now.get_year (), now.get_month (), 1, 0, 0, 0);
            last_month = new DateTime.local (now.get_year (), now.get_month (), 1, 0, 0, 0).add_months (-1);
            future = new DateTime.now_local ().add_days (1);

            from = from_date.date;  // might be null
            to = to_date.date;      // might be null
        }

        /**
         * Adds a list of transactions to the grid store
         */
        private void add_transactions (Gee.ArrayList<Transaction> transactions) {

            debug ("filtering and adding %d transactions".printf (transactions.size));

            populating_from_list = true;

            bool do_filter_search = search_term != null && search_term != "";
            var search = do_filter_search ? search_term.up () : "";

            DateTime this_month;
            DateTime last_month;
            DateTime future;
            DateTime? from;
            DateTime? to;

            get_filter_dates (out this_month, out last_month, out future, out from, out to);

            var iter = transactions.iterator ().filter ( (transaction) =>  {
                // filter on search term
                if (do_filter_search) {

                    var label = transaction.label.up ();
                    var desc = (transaction.description != null ? transaction.description : "").up ();

                    if (label.index_of (search) == -1 && desc.index_of (search) == -1) {
                        return false;
                    }
                }

                // honor date radio buttons
                var tdate = transaction.date;

                if (btn_this_month.get_active ()) {
                    if (tdate.get_year () == this_month.get_year () && tdate.get_month () == this_month.get_month ()) {
                        return true;
                    }

                    return false;
                }
                else if (btn_last_month.get_active ()) {
                    if (tdate.get_year () == last_month.get_year () && tdate.get_month () == last_month.get_month ()) {
                        return true;
                    }

                    return false;
                }
                else if (btn_future.get_active ()) {
                    return tdate.compare (future) >= 0;
                }
                else if (btn_manual.get_active ()) {
                    if (from != null && to != null) {
                        return from.compare (tdate) <= 0 && to.compare (tdate) >= 0;
                    }

                    return false;
                }

                return true;
            });

            var count = 0;

            while (iter.next ()) {
                add_transaction (iter.get());
                count++;
            }

            if (count > 0) {
                infobar.hide ();
                scroll_box.show_all ();
            }
            else {
                infobar.show_all ();
                scroll_box.hide ();
            }

            populating_from_list = false;
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

        private void update_view () {
            treeview.show_all ();
            //treeview.columns_autosize ();
        }

        private void apply_filters () {
            load_account (account);
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

            //var style_context = filter_box.get_style_context ();
            //style_context.add_class (Gtk.STYLE_CLASS_HIGHLIGHT);
            //style_context.add_class (Granite.StyleClass.CONTENT_VIEW);



            // import button
            var import_button = new Gtk.Button.with_label (_("Import\u2026"));
            filter_box.pack_start (import_button, false, false);

            import_button.clicked.connect (show_import_dialog);

            // this month
            btn_this_month = new Gtk.RadioButton (null);
            btn_this_month.label = _("This month");
            btn_this_month.toggled.connect ( () => {
                if (btn_this_month.get_active ()) {
                    load_account (account);
                }
            });
            filter_box.add (btn_this_month);

            // last month
            btn_last_month = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Last month"));
            btn_last_month.toggled.connect ( () => {
                if (btn_last_month.get_active ()) {
                    load_account (account);
                }
            });
            filter_box.add (btn_last_month);

            // future
            btn_future = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Future"));
            btn_future.toggled.connect ( () => {
                if (btn_future.get_active ()) {
                    load_account (account);
                }
            });
            filter_box.add (btn_future);

            // manual dates
            btn_manual = new Gtk.RadioButton.with_label_from_widget (btn_this_month, _("Pick dates:"));
            btn_manual.toggled.connect ( () => {
                if (btn_manual.get_active ()) {
                    from_date.sensitive = true;
                    to_date.sensitive = true;

                    if (from_date.date != null && to_date.date != null) {
                        load_account (account);
                    }
                }
                else {
                    from_date.sensitive = false;
                    to_date.sensitive = false;
                }
            });
            filter_box.add (btn_manual);

            from_date = new Granite.Widgets.DatePicker ();
            from_date.sensitive = false;
            from_date.date = new DateTime.now_local ().add_months (-1);

            // we need to be notified of date changes
            from_date.notify["date"].connect ( () => {
                if (btn_manual.get_active () && from_date.date != null && to_date.date != null) {
                    load_account (account);
                }
            });
            filter_box.add (from_date);

            to_date = new Granite.Widgets.DatePicker ();
            to_date.sensitive = false;
            to_date.date = new DateTime.now_local ();

            // we need to be notified of date changes
            to_date.notify["date"].connect ( () => {
                if (btn_manual.get_active () && from_date.date != null && to_date.date != null) {
                    load_account (account);
                }
            });
            filter_box.add (to_date);

            filter_box.show_all ();

            // infobar shown when filters do not return any transaction
            infobar = new Gtk.InfoBar /*.with_buttons (_("Clear filters"), InfoBarResponse.CLEAR, null)*/ ();
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

            add (grid_scroll);

            scroll_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            grid_scroll.add (scroll_box);
            scroll_box.show_all ();

            treeview = new Gtk.TreeView ();

            /*
             According to gtktreeview.c:4801, treeview line color is based on the border-top-color
             CSS property for the GtkTreeView. Black is ugly, and elementary gtk theme doesn't provide
             a custom value, so let's specify a value here. Might propose this in elementary-gtk-theme.
             */
            Granite.Widgets.Utils.set_theming (treeview, "GtkTreeView { border-top-color: #dddddd; }",
                null,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);


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
            treeview.enable_grid_lines = Gtk.TreeViewGridLines.BOTH;
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
            crdp.xalign = 1.0f;
            crdp.edited.connect ((path, text) => {

                if (crdp.date_selected) {
                    Gtk.TreeIter iter;

                    if (transactions_store.get_iter_from_string (out iter, path)) {
                        debug ("edited: setting date in store");
                        transactions_store.@set (iter, Column.DATE, text, -1);
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
            date_column.set_attributes (crdp, "text", Column.DATE);
            date_column.set_cell_data_func (crdp, cell_renderer_foreground_func);
            treeview.append_column (date_column);

            var merchant_column = new Gtk.TreeViewColumn ();
            merchant_column.set_title (_("Merchant"));
            merchant_column.max_width = -1;
            merchant_column.pack_start (renderer_label, true);
            merchant_column.resizable = true;
            merchant_column.set_cell_data_func (renderer_label, cell_renderer_foreground_func);
            merchant_column.set_attributes (renderer_label, "text", Column.MERCHANT);
            treeview.append_column (merchant_column);

            var category_column = new Gtk.TreeViewColumn ();
            category_column.set_title (_("Category"));
            category_column.max_width = -1;
            category_column.resizable = true;
            treeview.append_column (category_column);

            var out_column = new Gtk.TreeViewColumn ();
            out_column.set_title (_("Outflow"));
            out_column.max_width = -1;
            out_column.pack_start (renderer_out, true);
            out_column.resizable = true;
            out_column.set_cell_data_func (renderer_out, cell_renderer_foreground_func);
            out_column.set_attributes (renderer_out, "text", Column.OUTFLOW);
            treeview.append_column (out_column);

            var in_column = new Gtk.TreeViewColumn ();
            in_column.set_title (_("Inflow"));
            in_column.max_width = -1;
            in_column.pack_start (renderer_in, true);
            in_column.resizable = true;
            in_column.set_cell_data_func (renderer_in, cell_renderer_foreground_func);
            in_column.set_attributes (renderer_in, "text", Column.INFLOW);
            treeview.append_column (in_column);

            var memo_column = new Gtk.TreeViewColumn ();
            memo_column.set_title (_("Memo"));
            memo_column.max_width = -1;
            memo_column.pack_start (renderer_memo, true);
            memo_column.pack_end (crb, false);
            memo_column.resizable = true;
            memo_column.spacing = 10;
            memo_column.set_cell_data_func (renderer_memo, cell_renderer_foreground_func);
            memo_column.set_cell_data_func (crb, cell_renderer_badge_func);
            memo_column.set_attributes (renderer_memo, "text", Column.MEMO);
            treeview.append_column (memo_column);

            /*var badge_column = new Gtk.TreeViewColumn ();
            badge_column.pack_start (crb, true);
            badge_column.resizable = false;
            badge_column.set_cell_data_func (crb, cell_renderer_badge_func);
            treeview.append_column (badge_column);
            */

            grid_scroll.show_all ();
            treeview.show_all ();
        }

        private void cell_renderer_foreground_func (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
            /*
            Gtk.CellRendererText cr = renderer as Gtk.CellRendererText;
            Transaction? transaction = null;

            transactions_store.@get (iter, Column.TRANSACTION, out transaction, -1);

            if (transaction != null) {

                var now = new DateTime.now_local ();

                if (transaction.date.compare (now) == 1) {
                    // future transaction
                    //cr.foreground = "gray";
                    //cr.foreground_set = true;
                }
                else {
                    // now or past
                    //cr.foreground_set = false;
                }
            }
            else {

            }
            */
        }

        private void cell_renderer_badge_func (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
            Gtk.CellRendererText cr = renderer as Gtk.CellRendererText;
            Transaction? transaction = null;
            transactions_store.@get (iter, Column.TRANSACTION, out transaction, -1);
            cr.visible = transaction != null && transaction.date.compare (now) == 1;
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

        private void connect_signals () {
            /*notify["search_term"].connect ( () => {
                debug ("search term changed!");
                apply_filters ();
            });*/
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
