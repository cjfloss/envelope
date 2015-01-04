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

        private QIFImporter () {
            Object ();
            qif_importer_instance = this;
        }

        private static const char LINE_TYPE_TRANSACTION_DELIMITER                   = '^';
        private static const char LINE_TYPE_DATE                                    = 'D';
        private static const char LINE_TYPE_AMOUNT                                  = 'T';
        private static const char LINE_TYPE_MEMO                                    = 'M';
        private static const char LINE_TYPE_CLEARED                                 = 'C';
        private static const char LINE_TYPE_CHECK_NUM                               = 'C';
        private static const char LINE_TYPE_PAYEE                                   = 'P';
        private static const char LINE_TYPE_PAYEE_ADDRESS                           = 'A';
        private static const char LINE_TYPE_CATEGORY                                = 'L';
        private static const char LINE_TYPE_REIMBURSABLE                            = 'F';
        private static const char LINE_TYPE_SPLIT                                   = 'S';
        private static const char LINE_TYPE_SPLIT_MEMO                              = 'E';
        private static const char LINE_TYPE_SPLIT_AMOUNT                            = '$';
        private static const char LINE_TYPE_SPLIT_PERCENT                           = '%';
        private static const char LINE_TYPE_INVESTMENT                              = 'N';
        private static const char LINE_TYPE_SECURITY_NAME                           = 'Y';
        private static const char LINE_TYPE_PRICE                                   = 'I';
        private static const char LINE_TYPE_SHARE_QTY_SPLIT_RATIO                   = 'Q';
        private static const char LINE_TYPE_COMMISSION_COST                         = 'O';
        private static const char LINE_TYPE_QUICKEN_EXTENDED                        = 'X';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_SHIP_TO_ADDRESS        = 'A';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_TYPE                   = 'I';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_INVOICE_DUE_DATE       = 'E';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_TAX_ACCOUNT            = 'C';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_TAX_RATE               = 'R';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_TAX_AMOUNT             = 'T';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_LINE_ITEM_DESCRIPTION  = 'S';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_LINE_ITEM_CATEGORY     = 'N';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_LINE_ITEM_QTY          = '#';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_LINE_ITEM_UNIT_PRICE   = '$';
        private static const char LINE_TYPE_QUICKEN_EXTENDED_LINE_ITEM_TAXABLE      = 'F';

        private struct QIFTransaction {
            bool split;
            string date;
            double amount;
            string memo;
            string clear_status;
            string check_num;
            string payee;
            string payee_address;
            string category;
            string reimursable;
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

        public string date_delimiter { get; set; default = "/"; }

        /**
         * Import transactions from the QIF file specified by path
         *
         * @param string path the path to the QIF file
         * @return ArrayList<Transaction> the list of imported transactions
         * @throws ServiceError
         * @throws ImporterError
         */
        public ArrayList<Transaction> import (string path) throws ServiceError, ImporterError {

            ArrayList<Transaction> list = new ArrayList<Transaction> ();

            var file = File.new_for_path (path);

            if (!file.query_exists ()) {
                throw new ServiceError.ENOENT ("specified file does not exist");
            }

            try {

                var input_stream = file.read ();
                var stream = new DataInputStream (input_stream);

                // discard first line
                stream.read_line (); // eg.: !Type:Bank

                // now we must parse each section which are delimited by a single '^' line
                QIFTransaction transaction = QIFTransaction ();
                string? line = null;

                do {
                    line = stream.read_line ();

                    if (line != null && line.length > 0) {

                        if (!parse_line (line.strip (), ref transaction)) {

                            // transaction is complete; create a real Transaction object from the
                            // struct and add it to the list
                            Transaction trans;

                            if (transaction.split) {
                                // TODO find the first transaction which is split == false in the items before this one in the list
                                // this is the parent transaction
                            }

                            qif_transaction_to_transaction (transaction, out trans);

                            list.add (trans);

                            // try new transaction
                            transaction = QIFTransaction ();
                        }
                    }
                } while (line != null);
            }
            catch (Error err) {
                throw new ServiceError.IO (err.message);
            }

            info ("imported %d transactions from %s".printf (list.size, path));

            return list;
        }

        private bool parse_line (string line, ref QIFTransaction transaction) {

            assert (line.length > 0);

            char type = line.@get (0);

            if (type == LINE_TYPE_TRANSACTION_DELIMITER) {
                return false;
            }

            // skip if line type is not supported (yet)
            if (!line_type_supported (type)) {
                return true;
            }

            var payload = line.substring (1);

            switch (type) {
                case LINE_TYPE_SPLIT:
                    transaction.split = true;
                    transaction.category = payload;
                    break;

                case LINE_TYPE_SPLIT_MEMO:
                    transaction.split = true;
                    transaction.memo = payload;
                    break;

                case LINE_TYPE_SPLIT_AMOUNT:
                    transaction.split = true;
                    transaction.amount = double.parse (payload);
                    break;

                case LINE_TYPE_SPLIT_PERCENT:
                    transaction.split = true;
                    transaction.split_percentage = double.parse (payload);
                    break;

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

                case LINE_TYPE_CATEGORY:
                    transaction.category = payload;
                    break;

                 default:
                    debug ("type %s ignored".printf (type.to_string ()));
                    break;
            }

            return true;
        }

        private void qif_transaction_to_transaction (QIFTransaction transaction, out Transaction trans) {
            trans = new Transaction ();

            trans.label = transaction.payee.strip ();
            trans.description = transaction.memo != null ? transaction.memo.strip () : null;
            trans.amount = Math.fabs (transaction.amount);

            trans.direction = transaction.amount < 0 ?
                Transaction.Direction.OUTGOING :  Transaction.Direction.INCOMING;

            // parse date
            DateTime dt;
            if (!parse_qif_date_string (transaction.date, out dt)) {
                error ("could not parse date string %s".printf (transaction.date));
            }

            trans.date = dt;
        }

        // this is so wrong
        private bool parse_qif_date_string (string input, out DateTime date) {
            string[] tokens = input.split (date_delimiter);

            string year = tokens[2].strip ();
            if (year.length == 2) {
                year = "20" + year;
            }

            date = new DateTime.local (int.parse (year), int.parse (tokens[0]), int.parse (tokens[1]), 0, 0, 0d);

            return true;
        }

        private static bool line_type_supported (char type) {
            switch (type) {
                case LINE_TYPE_DATE:
                case LINE_TYPE_AMOUNT:
                case LINE_TYPE_MEMO:
                case LINE_TYPE_CLEARED:
                case LINE_TYPE_PAYEE:
                case LINE_TYPE_SPLIT:
                case LINE_TYPE_SPLIT_MEMO:
                case LINE_TYPE_SPLIT_AMOUNT:
                case LINE_TYPE_SPLIT_PERCENT:
                    return true;

                default:
                    return false;
            }
        }
    }
}
