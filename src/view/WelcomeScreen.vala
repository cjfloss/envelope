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

using Envelope.Dialog;

namespace Envelope.View {

    private static Welcome welcome_instance = null;

    public class Welcome : Granite.Widgets.Welcome {

        public static new unowned Welcome get_default () {
            if (welcome_instance == null) {
                welcome_instance = new Welcome ();
            }

            return welcome_instance;
        }

        public Welcome () {
            base (_("Get your budget going"), _("You have not configured any account yet"));
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            append ("add", _("Add an account"), _("Set up an account to record your transactions"));
        }

        private void connect_signals () {
            activated.connect (item_activated);
        }

        private void item_activated (int index ) {
            switch (index) {
                case 0:
                    var dialog = new AddAccountDialog ();

                    dialog.account_created.connect ((account) => {
                        dialog.destroy ();
                    });

                    dialog.show_all ();
                    break;

                default:
                    assert_not_reached ();
            }
        }
    }
}
