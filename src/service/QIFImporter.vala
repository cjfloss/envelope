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

namespace Envelope.Service {

    private static QIFImporter qif_importer_instance = null;

    public class QIFImporter : Object, Importer {

        construct {
            qif_importer_instance = this;
        }

        private static const char LINE_TYPE_TRANSACTION_DELIMITER = '^';
        private static const char LINE_TYPE_DATE = 'D';
        private static const char LINE_TYPE_AMOUNT = 'T';
        private static const char LINE_TYPE_MEMO = 'M';
        private static const char LINE_TYPE_CLEARED = 'C';
        private static const char LINE_TYPE_PAYEE = 'P';

        private struct QIFTransaction {
            string date;
            double amount;
            string memo;
            string clear_status;
            string check_num;
            string payee;
            string payee_address;
            string category;
            string reimursable;
            string split_category;
            string split_memo;
            double split_amount;
            double split_percentage;
            string inv_action;
            string security_name;
            string security_price;
            string share_qty;
            string comm_cost;
            double xfer_amount;
        }

        public static new unowned QIFImporter get_default () {
            if (qif_importer_instance == null) {
                qif_importer_instance = new QIFImporter ();
            }

            return qif_importer_instance;
        }

        public char date_delimiter { get; set; default = '/'; }
        public string date_format { get; set; default = "M/D/Y"; }

        /**
         *
         */
        public ArrayList<Transaction> import (string path) throws Error {

            debug ("importing transactions from %s".printf (path));

            var file = File.new_for_path (path);

            if (!file.query_exists ()) {
                error ("specified file does not exist");
            }

            var input_stream = file.read ();
            var stream = new DataInputStream (input_stream);

            var account_type = stream.read_line (); // eg.: !Type:Bank

            ArrayList<Transaction> list = new ArrayList<Transaction> ();

            // now we must parse each section which are delimited by a single '^' line
            QIFTransaction transaction = QIFTransaction ();
            string? line = null;

            do {
                line = stream.read_line ();

                if (line != null) {
                    if (!parse_line (line, ref transaction)) {
                        // transaction is complete; create a real Transaction object from the
                        // struct and add it to the list
                        Transaction trans = new Transaction ();

                        // TODO

                        list.add (trans);

                        transaction = QIFTransaction ();
                    }
                }
            } while (line != null);

            return list;
        }

        private bool parse_line (string line, ref QIFTransaction transaction) {

            char type = line[0];

            if (type == LINE_TYPE_TRANSACTION_DELIMITER) {
                return false;
            }

            var payload = line.substring (1);

            switch (type) {
                case LINE_TYPE_DATE:
                    transaction.date = payload;
                    break;

                case LINE_TYPE_AMOUNT:
                    transaction.amount = double.parse (payload);
                    break;

                case LINE_TYPE_MEMO:
                    transaction.memo = payload;
                    break;

                case LINE_TYPE_CLEARED:
                    transaction.clear_status = payload;
                    break;

                case LINE_TYPE_PAYEE:
                    transaction.payee = payload;
                    break;

                 default:
                    debug ("type %c ignored".printf (type));
                    break;
            }

            return true;
        }

        private void qif_transaction_to_transaction (QIFTransaction transaction, out Transaction trans) {
            trans = new Transaction ();

            trans.label = transaction.payee;
            trans.description = transaction.memo;
            trans.amount = transaction.amount;

            trans.direction = transaction.amount < 0 ?
                Transaction.Direction.INCOMING :  Transaction.Direction.OUTGOING;

            // parse date
            //Date date =
        }
    }
}
