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

    public class MainWindow : Gtk.ApplicationWindow {

        // window elements
        private Gtk.HeaderBar               header_bar;
        private Granite.Widgets.ThinPaned   paned;
        public static Sidebar               sidebar;
        private Gtk.MenuButton              app_menu;
        private Gtk.Menu                    settings_menu;
        private Gtk.MenuItem                preferences_menu_item;
        private Gtk.Box                     box;

        private DatabaseManager dbm = DatabaseManager.get_default ();

        public void build_ui () {

            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.add (box);

            app_menu = new Gtk.MenuButton ();
            settings_menu = new Gtk.Menu ();

            preferences_menu_item = new Gtk.MenuItem.with_label ("Preferences");

            var menu_icon = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.set_image (menu_icon);
            app_menu.popup = settings_menu;

            settings_menu.append (preferences_menu_item);
            settings_menu.show_all ();

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

                var transaction_view = TransactionView.get_default ();
                transaction_view.load_account (account);

                if (paned.get_child2 () != transaction_view) {
                    paned.remove (paned.get_child2 ());
                }

                paned.pack2 (transaction_view, true, false);
            });

            // If we have accounts, show the transaction view
            // otherwise show welcome screen
            Gtk.Widget content_view;
            determine_content_view (accounts, out content_view);
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

        private void determine_content_view (Gee.ArrayList<Account> accounts, out Gtk.Widget widget) {
            if (accounts.size > 0) {
                widget = TransactionView.get_default ();
            }
            else {
                widget = Welcome.get_default ();
            }
        }
    }
}
