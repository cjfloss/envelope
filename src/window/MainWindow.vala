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
using Envelope.View;
using Envelope.Service;
using Envelope.Service.Settings;

namespace Envelope.Window {

    public class MainWindow : Gtk.ApplicationWindow {

        // window elements
        public Gtk.HeaderBar                header_bar { get; private set; }
        public Gtk.Button                   import_button { get; private set; }
        public Gtk.SearchEntry              search_entry { get; private set; }
        public Sidebar                      sidebar { get; private set; }
        public Gtk.MenuButton               app_menu { get; private set; }
        public Menu                         settings_menu { get; private set; }
        public Granite.Widgets.OverlayBar   overlay_bar {get; private set; }

        private Granite.Widgets.ThinPaned   paned;
        private Gtk.MenuItem                preferences_menu_item;
        private Gtk.Popover                 menu_popover;
        private Gtk.Overlay                 overlay;

        private DatabaseManager dbm = DatabaseManager.get_default (); // TODO replace this with a call to AccountManager

        // fired when the content view changes
        public signal void main_view_changed (Gtk.Widget main_view);

        public MainWindow () {
            Object ();

            build_ui ();
            connect_signals ();
        }

        public void show_notification (string text) {
            overlay_bar.hide ();
            overlay_bar.status = text;

            overlay_bar.show ();

            Timeout.add (Envelope.App.TOAST_TIMEOUT, () => {
                overlay_bar.hide ();
                return false;
            });
        }

        private void build_ui () {

            overlay = new Gtk.Overlay ();
            this.add (overlay);

            overlay_bar = new Granite.Widgets.OverlayBar (overlay);

            app_menu = new Gtk.MenuButton ();
            settings_menu = new Menu ();

            preferences_menu_item = new Gtk.MenuItem.with_label ("Preferences");

            var menu_icon = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.set_image (menu_icon);
            settings_menu.append (_("Preferences"), null);
            menu_popover = new Gtk.Popover.from_model (app_menu, settings_menu);
            app_menu.popover = menu_popover;

            paned = new Granite.Widgets.ThinPaned ();

            header_bar = new Gtk.HeaderBar ();
            header_bar.show_close_button = true;
            set_titlebar (header_bar);

            header_bar.pack_end (app_menu);

            // import button
            import_button = new Gtk.Button.from_icon_name ("document-import", Gtk.IconSize.LARGE_TOOLBAR);
            import_button.tooltip_text = _("Import transactions");
            header_bar.pack_start (import_button);

            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search transactions\u2026");

            var search_entry_completion = new Gtk.EntryCompletion ();
            search_entry_completion.set_model (MerchantStore.get_default ());
            search_entry_completion.set_text_column (0);
            search_entry_completion.popup_completion = true;
            search_entry_completion.set_match_func ( (completion, key, iter) => {

                if (key.length == 0) {
                    return false;
                }

                string store_value;
                MerchantStore.get_default ().@get (iter, 0, out store_value, -1);

                if (store_value.up ().index_of (key.up ()) != -1) {
                    return true;
                }

                return false;
            });

            search_entry.completion = search_entry_completion;

            header_bar.pack_end (search_entry);
            header_bar.show_all ();

            // sidebar
            sidebar = new Sidebar ();
            paned.pack1 (sidebar, true, false);

            Gee.ArrayList<Account> accounts = dbm.load_all_accounts ();
            sidebar.accounts = accounts;

            sidebar.update_view ();
            sidebar.show_all ();

            sidebar.list_account_selected.connect ((account) => {
                Gtk.Widget widget;
                determine_content_view (account, out widget);

                Type t = widget.get_type ();

                debug ("view to show: %s".printf (t.name ()));

                if (paned.get_child2 () != widget) {
                    var current_view = paned.get_child2 ();
                    current_view.@ref ();
                    paned.remove (current_view);
                }

                paned.add2 (widget);
                paned.show_all ();

                main_view_changed (widget);
            });

            // If we have accounts, show the transaction view
            // otherwise show welcome screen
            Gtk.Widget content_view;
            determine_initial_content_view (accounts, out content_view);
            paned.pack2 (content_view, true, false);

            paned.position = 250;
            paned.position_set = true;
            paned.show_all ();

            overlay.add (paned);
            overlay.show_all ();
            overlay_bar.hide ();

            this.width_request = 1200;
            this.height_request = 800;


            // restore state
            var saved_state = SavedState.get_default ();

            this.window_position = saved_state.window_position != null ?
                saved_state.window_position : Gtk.WindowPosition.CENTER;

            if (saved_state.window_state == Gdk.WindowState.MAXIMIZED) {
                maximize ();
            }
            else if (saved_state.window_width != null && saved_state.window_height != null) {
                width_request = saved_state.window_width;
                height_request = saved_state.window_height;
            }
        }

        private void connect_signals () {

            destroy.connect (on_quit);

            // connect signals
            TransactionWelcomeScreen.get_default ().add_transaction_selected.connect ( (account) => {

                var transaction_view = TransactionView.get_default ();
                var current_view = paned.get_child2 ();
                current_view.@ref ();

                paned.remove (current_view);
                paned.add2 (transaction_view);
                transaction_view.load_account (account);
            });

            // handle account renames
            Sidebar.get_default ().list_account_name_updated.connect ( (account, new_name) => {

                Account acct = account as Account;

                if (acct.number != new_name) {

                    try {
                        AccountManager.get_default ().rename_account (ref acct, new_name);
                    }
                    catch (Error err) {
                        if (err is ServiceError.DATABASE_ERROR) {

                        }
                        else if (err is AccountError.ALREADY_EXISTS) {

                        }

                        // TODO reset the label in the sidebar to the original account number
                    }
                }
            });

            main_view_changed.connect ( (window, widget) => {
                // check if we need to show the transaction search entry
                if (widget is TransactionView) {
                    import_button.show ();
                    search_entry.show ();
                    search_entry.text = "";
                }
                else if (widget is TransactionWelcomeScreen) {
                    import_button.show ();
                }
                else {
                    import_button.hide();
                    search_entry.hide ();
                    search_entry.text = "";
                }
            });

            search_entry.search_changed.connect ( (entry) => {
                debug ("search changed to %s".printf (entry.text));
                TransactionView.get_default ().set_search_filter (entry.text);
            });

            import_button.clicked.connect ( () => {
                TransactionView.get_default ().show_import_dialog ();
            });
        }

        private void determine_initial_content_view (Gee.ArrayList<Account> accounts, out Gtk.Widget widget) {
            if (accounts.size > 0) {
                widget = BudgetOverview.get_default ();
            }
            else {
                widget = Welcome.get_default ();
            }
        }

        private void determine_content_view (Account account, out Gtk.Widget widget) {

            var transactions = dbm.load_account_transactions (account.@id);
            account.transactions = transactions;

            if (transactions.size == 0) {
                widget = TransactionWelcomeScreen.get_default ();
                (widget as TransactionWelcomeScreen).account = account;
            }
            else {
                widget = TransactionView.get_default ();
                (widget as TransactionView).load_account (account);
            }
        }

        private void on_quit () {
            save_settings ();
        }

        private void restore_settings () {
            var saved_state = SavedState.get_default ();

        }

        private void save_settings () {
            var saved_state = SavedState.get_default ();

            // get window dimensions
            int height;
            int width;

            get_size (out width, out height);

            saved_state.window_height = height;
            saved_state.window_width = width;
            saved_state.window_state = get_window ().get_state ();

            // sidebar width
            saved_state.sidebar_width = paned.get_position ();

            // search
            saved_state.search_term = search_entry.text;
        }
    }
}
