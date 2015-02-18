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

using Gee;

namespace Envelope {

    public class Account : Object, Comparable<Account> {

        public enum Type {
            CHECKING,
            SAVINGS;

            public static Type from_int (int type_int) {
                switch (type_int) {
                    case 0:
                        return CHECKING;

                    case 1:
                        return SAVINGS;

                    default:
                        assert_not_reached ();
                }
            }
        }

        public Gee.List<Transaction> transactions { get; set; }
        public string number { get; set; }
        public string description { get; set; }
        public Type account_type { get; set; default = Type.CHECKING; }
        public double balance { get; set; default = 0d; }
        public int @id { get; set; }

        public bool has_transactions { get {
            return transactions != null && transactions.size > 0;
        } }

        public Account () {
            transactions = new Gee.ArrayList<Transaction> ();
        }

        public Account.with_number (string number) {
            this();
            this.number = number;
        }

        public Account.from_transaction_list (ref ArrayList<Transaction> transactions) {
            this();
            this.transactions = transactions;
        }

        public void record_transaction (Transaction transaction) {
            switch (transaction.direction) {
                case Transaction.Direction.INCOMING:
                    balance += transaction.amount;
                    break;

                case Transaction.Direction.OUTGOING:
                    balance -= transaction.amount;
                    break;
            }

            transactions.add (transaction);
        }

        public void delete_transaction (Transaction transaction) {
            switch (transaction.direction) {
                case Transaction.Direction.INCOMING:
                balance += transaction.amount;
                break;

                case Transaction.Direction.OUTGOING:
                balance -= transaction.amount;
                break;
            }

            // TODO remove from list

        }

        public int compare_to (Account account) {
            return 1;
        }
    }
}
