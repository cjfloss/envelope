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

    public class Welcome : Gtk.Grid {
        construct {
            var welcome = new Granite.Widgets.Welcome ("Get your budget going",
                    "You have not configured any account yet");
            welcome.append ("list-add-symbolic", _("Add an account"),
                    _("You have not configured any account yet"));
            welcome.append ("list-remove-symbolic", _("test an account"),
                    _("You have not configured any account yet"));

            add (welcome);

            welcome.activated.connect ((index) => {
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
            });
        }

        public static new unowned Welcome get_default () {
            if (welcome_instance == null) {
                welcome_instance = new Welcome ();
            }

            return welcome_instance;
        }
    }
}
