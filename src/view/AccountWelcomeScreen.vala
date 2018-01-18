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

namespace Envelope.View {
    public class AccountWelcomeScreen : Granite.Widgets.Welcome {
        private static AccountWelcomeScreen account_welcome_screen_instance = null;

        public static new AccountWelcomeScreen get_default () {
            if (account_welcome_screen_instance == null) {
                account_welcome_screen_instance = new AccountWelcomeScreen ();
            }

            return account_welcome_screen_instance;
        }

        private enum Action {
            ADD_TRANSACTION,
            IMPORT_TRANSACTIONS
        }

        public Account account { get; set; }

        public signal void add_transaction_selected (Account account);

        public AccountWelcomeScreen () {
            base (_("Spend! Get paid!"), _("There are currently no transactions in this account"));
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            append ("add", _("Record a transaction"),
            _("Record a fresh new transaction for this account. Or, plan a future one!"));

            append ("document-import", _("Import transactions"),
            _("Import from a QIF file obtained from another application"));

            show_all ();
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
                    view.transactions = account.transactions;
                    view.show_import_dialog ();
                    break;
                default:
                    assert_not_reached ();
            }
        }
    }
}
