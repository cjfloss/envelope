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

        private static const uint TRANSITION_DURATION = 0;

        // window elements
        public Gtk.HeaderBar                header_bar { get; private set; }
        public Gtk.Button                   import_button { get; private set; }
        //public Gtk.Button                   export_button { get; private set; }
        public Gtk.Button                   add_transaction_button { get; private set; }
        public Gtk.SearchEntry              search_entry { get; private set; }
        public Sidebar                      sidebar { get; private set; }
        public Gtk.MenuButton               app_menu { get; private set; }
        public Menu                         settings_menu { get; private set; }
        public Granite.Widgets.OverlayBar   overlay_bar {get; private set; }

        private Gtk.Paned                   paned;
        private Gtk.MenuItem                preferences_menu_item;
        private Gtk.Popover                 menu_popover;
        private Gtk.Overlay                 overlay;

        private AccountManager              account_manager = AccountManager.get_default ();
        private BudgetManager               budget_manager = BudgetManager.get_default ();

        // fired when the content view changes
        public signal void main_view_changed (Gtk.Widget main_view);

        public MainWindow () {
            Object ();

            build_ui ();
            connect_signals ();
            configure_window ();
        }

        /**
         * Show a brief message in the overlay bar for a specified time, then hide it afterwards
         */
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

            // overlay bar for toast notifitcations
            overlay_bar = new Granite.Widgets.OverlayBar (overlay);

            // Menus
            app_menu = new Gtk.MenuButton ();
            settings_menu = new Menu ();

            preferences_menu_item = new Gtk.MenuItem.with_label ("Preferences");

            var menu_icon = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.set_image (menu_icon);
            settings_menu.append (_("Export..."), null);
            menu_popover = new Gtk.Popover.from_model (app_menu, settings_menu);
            app_menu.popover = menu_popover;

            // main paned widget
            paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            paned.position = 250;
            paned.position_set = true;
            overlay.add (paned);

            // header bar
            header_bar = new Gtk.HeaderBar ();
            header_bar.show_close_button = true;
            set_titlebar (header_bar);

            // import button
            import_button = new Gtk.Button.from_icon_name ("document-import", Gtk.IconSize.LARGE_TOOLBAR);
            import_button.tooltip_text = _("Import transactions");
            header_bar.pack_start (import_button);

            // export button
            //export_button = new Gtk.Button.from_icon_name ("document-export", Gtk.IconSize.LARGE_TOOLBAR);
            //export_button.tooltip_text = _("Backup budget");
            //header_bar.pack_end (export_button);

            // add transaction button
            add_transaction_button = new Gtk.Button.from_icon_name ("document-new", Gtk.IconSize.LARGE_TOOLBAR);
            add_transaction_button.tooltip_text = _("Record transaction");
            header_bar.pack_start (add_transaction_button);

            // search entry & completion
            search_entry = new Gtk.SearchEntry ();
            search_entry.width_chars = 30;
            search_entry.placeholder_text = _("Search transactions\u2026");

            var search_entry_completion = new Gtk.EntryCompletion ();
            search_entry_completion.set_model (MerchantStore.get_default ());
            search_entry_completion.set_text_column (MerchantStore.COLUMN);
            search_entry_completion.popup_completion = true;
            search_entry_completion.set_match_func ( (completion, key, iter) => {

                if (key.length == 0) {
                    return false;
                }

                string store_value;
                MerchantStore.get_default ().@get (iter, MerchantStore.COLUMN, out store_value, -1);

                return store_value.up ().index_of (key.up ()) != -1;
            });

            search_entry.completion = search_entry_completion;
            header_bar.pack_end (search_entry);

            header_bar.show_all ();

            // sidebar
            sidebar = Sidebar.get_default ();

            Gee.Collection<Account> accounts;

            try {
                accounts = AccountManager.get_default ().get_accounts ();
                sidebar.accounts = accounts;
            }
            catch (ServiceError err) {
                error ("could not load accounts (%s)", err.message);
            }

            sidebar.update_view ();



            // If we have accounts, show the transaction view
            // otherwise show welcome screen
            Gtk.Widget content_view;
            determine_initial_content_view (accounts, out content_view);

            set_content_view (content_view);

            // done! show all
            overlay.show_all ();
            overlay_bar.hide ();
        }

        private void on_sidebar_account_selected (Account account) {
          Gtk.Widget widget;
          string window_title;
          determine_account_content_view (account, out widget, out window_title);

          set_content_view (widget);

          if (widget is TransactionView) {
              TransactionView transaction_view = widget as TransactionView;
              transaction_view.with_filter_view = true;
              transaction_view.with_add_transaction_view = true;
          }

          search_entry.placeholder_text = "Search in %s".printf (account.number);

          header_bar.title = window_title;
          header_bar.has_subtitle = false;
          header_bar.subtitle = "";

          var saved_state = SavedState.get_default ();
          saved_state.selected_category_id = -1;
          saved_state.selected_account_id = account.@id;
        }

        private void configure_window () {

            // configure window
            width_request = 1200;
            height_request = 800;

            debug ("restoring saved application state");

            // restore state
            var saved_state = SavedState.get_default ();

            if (saved_state.maximized) {
                get_window ().maximize ();
            }
            else if (saved_state.window_width != -1 && saved_state.window_height != -1) {
                set_default_size (saved_state.window_width, saved_state.window_height);
            }

            search_entry.text = saved_state.search_term;

            if (saved_state.selected_account_id != -1) {
                // TODO check if account still exists
                sidebar.select_account_by_id (saved_state.selected_account_id);
            }
            else if (saved_state.selected_category_id != -1) {
                // TODO check if category still exists
                sidebar.select_category_by_id (saved_state.selected_category_id);
            }

            paned.set_position (saved_state.sidebar_width);
        }

        private void on_account_welcome_screen_add_transaction_selected (Account account) {
          var transaction_view = TransactionView.get_default ();

          set_content_view (transaction_view);
          transaction_view.transactions = account.transactions;
        }

        private void on_sidebar_list_account_name_updated (Account account, string new_name) {

          if (account.number != new_name) {

              try {
                  AccountManager.get_default ().rename_account (account, new_name);
              }
              catch (Error err) {
                  if (err is ServiceError.DATABASE_ERROR) {
                      error ("error renaming account (%s)", err.message);
                  }
                  else if (err is AccountError.ALREADY_EXISTS) {
                      // TODO show error
                  }
              }
          }
        }

        private void on_sidebar_list_category_name_updated (Category category, string new_name) {
          string old_name = category.name;

          if (category.name != new_name) {
              try {
                category.name = new_name;
                  budget_manager.update_category (category);
              }
              catch (ServiceError err) {
                category.name = old_name;
                  if (err is ServiceError.DATABASE_ERROR) {
                      error ("could not update category (%s)", err.message);
                  }
              }
          }
        }

        private void on_sidebar_overview_selected () {
          var budget_overview = BudgetOverview.get_default ();

          if (paned.get_child2 () != budget_overview) {
              set_content_view (budget_overview);
          }
        }

        private void on_sidebar_category_selected (Category? category) {
          var transaction_view = TransactionView.get_default ();

          try {
              double inflow, outflow;
              var transactions = budget_manager.compute_current_category_operations (category, out inflow, out outflow);

              transaction_view.transactions = transactions;
              transaction_view.with_filter_view = false;
              transaction_view.with_add_transaction_view = false;

              if (paned.get_child2 () != transaction_view) {
                  set_content_view (transaction_view);
              }

              header_bar.title = category != null ? category.name : _("Uncategorized");
              header_bar.subtitle = new DateTime.now_local ().format ("%B %Y");
              header_bar.has_subtitle = true;

              if (category != null) {
                search_entry.placeholder_text = _("Search in %s".printf (category.name));
              }
              else {  // uncategorized
                search_entry.placeholder_text = _("Search uncategorized");
              }

              var saved_state = SavedState.get_default ();
              saved_state.selected_category_id = category != null ? category.@id : -1;
              saved_state.selected_account_id = -1;
          }
          catch (ServiceError err) {
              error ("could not load transactions for category %s (%s)", category.name, err.message);
          }
        }

        private void connect_signals () {

            delete_event.connect (on_quit);

            sidebar.list_account_selected.connect (on_sidebar_account_selected);

            // connect signals
            AccountWelcomeScreen.get_default ().add_transaction_selected.connect (on_account_welcome_screen_add_transaction_selected);

            // handle account renames
            sidebar.list_account_name_updated.connect (on_sidebar_list_account_name_updated);

            // handle category renames
            sidebar.list_category_name_updated.connect (on_sidebar_list_category_name_updated);

            sidebar.overview_selected.connect (on_sidebar_overview_selected);

            sidebar.category_selected.connect (on_sidebar_category_selected);

            main_view_changed.connect ( (window, widget) => {
                // check if we need to show the transaction search entry
                if (widget is TransactionView) {

                    import_button.show ();
                    add_transaction_button.show ();
                    search_entry.show ();

                    // show sidebar if it was not there yet
                    if (paned.get_child1 () == null) {
                        paned.pack1 (Sidebar.get_default (), true, false);
                    }
                }
                else if (widget is AccountWelcomeScreen) {
                    header_bar.title = null;
                    import_button.show ();
                    add_transaction_button.show ();

                    if (paned.get_child1 () == null) {
                        paned.pack1 (Sidebar.get_default (), true, false);
                    }
                }
                else if (widget is BudgetOverview) {
                    header_bar.title = null;
                }
                else {
                    import_button.hide();
                    add_transaction_button.hide ();
                    search_entry.hide ();
                }
            });

            search_entry.search_changed.connect ( (entry) => {
                debug ("search changed to %s".printf (entry.text));
                TransactionView.get_default ().set_search_filter (entry.text);
            });

            import_button.clicked.connect ( () => {
                TransactionView.get_default ().show_import_dialog ();
            });

            add_transaction_button.clicked.connect ( () => {
                var child = paned.get_child2 ();

                if (!(child is TransactionView)) {
                    set_content_view (TransactionView.get_default ());
                }

                TransactionView.get_default ().btn_add_transactions_clicked ();
            });

            account_manager.transaction_recorded.connect ( () => {
                Envelope.App.toast (_("Transaction recorded"));
            });

            account_manager.account_created.connect ( () => {
                if (paned.get_child1 () == null) {
                    paned.pack1 (sidebar, true, false);
                }

                sidebar.show_all ();
            });

            account_manager.transactions_imported.connect ( (transactions, account) => {
                sidebar.select_account (account);
            });
        }

        private void determine_initial_content_view (Gee.Collection<Account> accounts, out Gtk.Widget widget) {
            if (accounts.size > 0) {
                widget = BudgetOverview.get_default ();
            }
            else {
                widget = Welcome.get_default ();
            }

            if (widget != Welcome.get_default ()) {
                if (paned.get_child1 () == null) {
                    paned.pack1 (sidebar, true, false);
                }
            }
            else {
                search_entry.hide ();
                import_button.hide ();
                add_transaction_button.hide ();
            }
        }

        private void determine_account_content_view (Account account, out Gtk.Widget widget, out string window_title) {

            try {
                var transactions = AccountManager.get_default ().load_account_transactions (account);
                account.transactions = transactions;

                if (transactions.size == 0) {
                    widget = AccountWelcomeScreen.get_default ();
                    (widget as AccountWelcomeScreen).account = account;
                    window_title = null;
                }
                else {
                    widget = TransactionView.get_default ();
                    (widget as TransactionView).transactions = account.transactions;
                    window_title = _("Transactions in %s").printf (account.number);
                }
            }
            catch (ServiceError err) {
                error ("could not load account transactions (%s)", err.message);
            }
        }

        private bool on_quit (Gdk.EventAny event) {
            save_settings ();
            return false;
        }

        private void save_settings () {
            var saved_state = SavedState.get_default ();

            // get window dimensions
            int height;
            int width;
            get_size (out width, out height);

            saved_state.window_height = height;
            saved_state.window_width = width;
            saved_state.maximized = get_window ().get_state () == Gdk.WindowState.MAXIMIZED;

            // sidebar width
            saved_state.sidebar_width = paned.get_position ();

            // search
            saved_state.search_term = search_entry.text;
        }

        private void set_content_view (Gtk.Widget widget) {

            var child = paned.get_child2 ();

            if (child != null) {

                paned.remove (child);

                if (child != widget) {
                    child.@ref ();
                }
            }

            paned.pack2 (widget, true, false);

            widget.show ();

            main_view_changed (widget);
        }
    }
}
