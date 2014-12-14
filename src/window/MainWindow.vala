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

namespace Envelope.Window {

    public class MainWindow : Gtk.ApplicationWindow {

        // window elements
        private Gtk.HeaderBar               header_bar;
        private Granite.Widgets.ThinPaned   paned;
        public static Sidebar               sidebar;
        private Gtk.MenuButton              app_menu;
        private Menu                        settings_menu;
        private Gtk.MenuItem                preferences_menu_item;
        private Gtk.Box                     box;
        private Gtk.Popover                 menu_popover;

        private DatabaseManager dbm = DatabaseManager.get_default ();

        public MainWindow () {
            Object ();

            build_ui ();
            connect_signals ();
        }

        private void build_ui () {

            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.add (box);

            app_menu = new Gtk.MenuButton ();
            settings_menu = new Menu ();

            preferences_menu_item = new Gtk.MenuItem.with_label ("Preferences");

            var menu_icon = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.set_image (menu_icon);

            settings_menu.append (_("Preferences"), null);
            //settings_menu.show_all ();

            menu_popover = new Gtk.Popover.from_model (app_menu, settings_menu);

            app_menu.popover = menu_popover;

            paned = new Granite.Widgets.ThinPaned ();

            header_bar = new Gtk.HeaderBar ();
            header_bar.show_close_button = true;
            set_titlebar (header_bar);

            header_bar.pack_end (app_menu);

            var search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search transactions\u2026");
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
            });

            // If we have accounts, show the transaction view
            // otherwise show welcome screen
            Gtk.Widget content_view;
            determine_initial_content_view (accounts, out content_view);
            paned.pack2 (content_view, true, false);

            paned.position = 250;
            paned.position_set = true;
            paned.show_all ();

            box.add (paned);
            box.show_all ();

            this.width_request = 1200;
            this.height_request = 780;
            this.window_position = Gtk.WindowPosition.CENTER;
        }

        private void connect_signals () {
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
                    catch (err) {
                        if (err is ServiceError.DATABASE_ERROR) {

                        }
                        else if (err is AccountError.ALREADY_EXISTS) {

                        }

                        // TODO reset the label in the sidebar to the original account number
                    }
                }
            });
        }

        private void determine_initial_content_view (Gee.ArrayList<Account> accounts, out Gtk.Widget widget) {
            if (accounts.size > 0) {
                widget = TransactionView.get_default ();
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
    }
}
