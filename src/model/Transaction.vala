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
    public class Transaction : Object, Gee.Comparable<Transaction> {

        public enum Direction {
            INCOMING,
            OUTGOING;

            public static Direction from_int (int direction) {
                switch (direction) {
                    case 0:
                        return Direction.INCOMING;
                    case 1:
                        return Direction.OUTGOING;
                    default:
                        assert_not_reached ();
                }
            }
        }

        private int _id;

        private string _label;
        private string _description;

        private Transaction.Direction _direction;

        private double _amount;

        private Account _account;

        private Transaction _parent;

        private DateTime _date;

        public Transaction () {
            _amount = 0d;
            _label = "Untitled";
            _description = "";
            _account = null;
        }

        public Transaction.from_parent (ref Transaction transaction) {
            this();
            _parent = transaction;
        }

        public string label {
            get { return _label; }
            set {
                if (value == null || value == "") {
                    // TODO critical setting null or empty label
                    debug ("cannot set value");
                }
                else {
                    _label = value;
                }
            }
        }

        public string description {
            get { return _description; }
            set { _description = value; }
        }

        public Transaction.Direction direction {
            get { return _direction; }
            set { _direction = value; }
        }

        public double amount {
            get { return _amount; }
            set {
                if (value < 0d) {
                    // TODO critical trying to set negative value
                    debug ("cannot set value");
                }
                else {
                    _amount = value;
                }
            }
        }

        public Account account {
            get { return _account; }
            set { _account = value; }
        }

        public DateTime date {
            get { return _date; }
            set { _date = value; }
        }

        public int @id {
            get { return _id; }
            set { _id = value; }
        }

        public Transaction? parent {
            get { return _parent; }
            set { _parent = value; }
        }

        // compare by date
        public int compare_to (Transaction transaction) {
            return -_date.compare(transaction.date);
        }
    }
}
