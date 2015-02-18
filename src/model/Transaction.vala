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

    public class Transaction : Object, Comparable<Transaction> {

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

        public string label { get; set; }
        public string description { get; set; }
        public Transaction.Direction direction { get; set; }
        public double amount { get; set; }
        public Account account { get; set; }
        public DateTime date { get; set; }
        public int? @id { get; set; }
        public Transaction? parent { get; set; }
        public Category? category { get; set; }

        public Transaction () {
            amount = 0d;
            label = "Untitled";
            description = "";
            account = null;
        }

        public Transaction.from_parent (ref Transaction transaction) {
            this();
            parent = transaction;
        }

        // compare by date
        public int compare_to (Transaction transaction) {
            return -date.compare(transaction.date);
        }
    }
}
