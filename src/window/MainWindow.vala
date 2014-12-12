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

    public class MainWindow : Gtk.Window {

        // window elements
        private Gtk.HeaderBar header_bar;
        private Granite.Widgets.ThinPaned paned;
        public static Sidebar sidebar;
        private Gtk.MenuButton app_menu;
        private Gtk.Menu settings_menu;
        private Gtk.MenuItem preferences_menu_item;
        private Gtk.Box box;
        private Welcome welcome;

        // for testing purposes
        private TransactionView transaction_view;

        private DatabaseManager dbm = DatabaseManager.get_default ();

        public MainWindow () {

        }

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

            Gee.ArrayList<Account> accounts = DatabaseManager.get_default ().load_all_accounts ();
            sidebar.accounts = accounts;

            sidebar.update_view ();
            sidebar.show_all ();

            sidebar.list_account_selected.connect ((account) => {
                transaction_view.load_account (account);

                if (paned.get_child2 () != transaction_view) {
                    paned.remove (paned.get_child2 ());
                }

                paned.pack2 (transaction_view, true, false);

            });

            welcome = new Welcome ();
            transaction_view = new TransactionView ();

            paned.pack2 (welcome, true, false);

            box.add (paned);

            paned.show_all ();

            box.show_all ();

            //this.set_default_size (800, 600);
            this.width_request = 1200;
            this.height_request = 680;
            this.window_position = Gtk.WindowPosition.CENTER;
            this.title = "envelope";
        }

        private Gee.ArrayList<Transaction> get_mocked_transactions () {
            Gee.ArrayList<Transaction> list = new Gee.ArrayList<Transaction> ();

            for (int i = 0; i < 10; i++) {
                var trans = new Transaction ();

                trans.label = "transaction %d".printf (i);
                trans.amount = 100 + i;

                trans.date = new DateTime.now_local ().add_days (i);

                trans.direction = i % 2 == 0 ? Transaction.Direction.INCOMING : Transaction.Direction.OUTGOING;

                trans.description = "description for %d".printf (i);

                trans.@id = i;

                list.add (trans);

                if (i == 4) {
                    var child = new Transaction ();
                    child.label = "child transaction";
                    child.amount = 259.34;
                    child.direction = Transaction.Direction.INCOMING;
                    child.date = new DateTime.now_local ();
                    child.description = "this is a child";

                    child.parent = trans;

                    child.@id = i * 2000;

                    list.add (child);
                }


            }

            // Transaction is comparable; sort
            list.sort();

            return list;
        }
    }


}
