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
using Envelope.DB;

namespace Envelope.Service {

    public errordomain AccountError {
        ALREADY_EXISTS
    }

    private static AccountManager account_manager_instance = null;

    public class AccountManager : Object {

        public static new unowned AccountManager get_default () {
            if (account_manager_instance == null) {
                account_manager_instance = new AccountManager ();
            }

            return account_manager_instance;
        }

        private AccountManager () {
            Object ();
            account_manager_instance = this;
        }

        private DatabaseManager dbm = DatabaseManager.get_default ();

        public signal void account_created (Account account);
        public signal void account_updated (Account account);
        public signal void account_deleted (Account account);

        public signal void transaction_recorded     (Transaction transaction);
        public signal void transactions_imported    (ArrayList<Transaction> transactions, Account account);
        public signal void transaction_updated      (Transaction transaction);
        public signal void transaction_deleted      (Transaction transaction);

        public Collection<Account> get_accounts () throws ServiceError {

            try {
                return dbm.load_all_accounts ();
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public bool get_account_by_id (int account_id, out Account? account) throws ServiceError {


            // load from database
            try {
                account = dbm.load_account (account_id);
                return account != null;
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Create a new account
         *
         * @return Account the new account
         * @throws AccountError
         * @throws ServiceError
         */
        public Account create_account (string number,
                                       string? description,
                                       double balance,
                                       Account.Type account_type) throws AccountError, ServiceError {

            var account = new Account ();

            account.number = number;
            account.description = description;
            account.balance = balance;
            account.account_type = account_type;

            try {
                dbm.create_account (account);
                account_created (account);

                return account;
            }
            catch (SQLHeavy.Error err) {
                if (err is SQLHeavy.Error.CONSTRAINT) {
                    throw new AccountError.ALREADY_EXISTS ("account number already exists");
                }

                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void delete_account (Account account) throws ServiceError {

            try {
                dbm.delete_account (account);
                account_deleted (account);
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Rename an account. The account object will be updated with the new number upon successful operation.
         *
         * @param Account account - the account to rename
         * @param string new_number - the new account number
         *
         * @return bool true if transaction suceedded, false otherwise
         */
        public void rename_account (Account account, string new_number) throws AccountError, ServiceError {
            try {
                dbm.rename_account (account, new_number);
                account.number = new_number;

                // fire signal
                account_updated (account);
            }
            catch (SQLHeavy.Error err) {
                if (err is SQLHeavy.Error.CONSTRAINT) {
                    throw new AccountError.ALREADY_EXISTS ("account number already exists");
                }

                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void update_account_balance (ref Account account) throws ServiceError {
            try {
                var db_transaction = dbm.start_transaction ();
                dbm.update_account_balance (account, ref db_transaction);
                db_transaction.commit ();
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public Gee.List<Transaction> load_account_transactions (Account account) throws ServiceError {
            try {
                return dbm.load_account_transactions (account);
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public Transaction record_transaction (ref Account account, DateTime date, string label, string description, double amount, Category? category, Transaction? parent = null) throws ServiceError {

            var old_balance = account.balance;

            try {

                Transaction transaction = new Transaction ();

                transaction.label = label;
                transaction.parent = parent;
                transaction.date = date;
                transaction.description = description;
                transaction.direction = amount > 0d ? Transaction.Direction.INCOMING : Transaction.Direction.OUTGOING;
                transaction.amount = Math.fabs (amount);
                transaction.account = account;

                if (category != null) {
                    transaction.category = category;
                }

                var db_transaction = dbm.start_transaction ();

                dbm.insert_transaction (transaction, ref db_transaction);

                adjust_balance (account, transaction);
                dbm.update_account_balance (account, ref db_transaction);

                db_transaction.commit ();

                account.transactions.add (transaction);
                account.transactions.sort ();

                transaction_recorded (transaction);
                account_updated (account);

                return transaction;
            }
            catch (SQLHeavy.Error err) {
                account.balance = old_balance;
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void update_transaction (Transaction transaction) throws ServiceError {


            var old_balance = transaction.account.balance;

            try {

                // load transaction as it is before update to correctly recalculate account balance
                var current_transaction = dbm.get_transaction_by_id (transaction.@id);

                // should not be null, we're updating an existing transaction
                assert (current_transaction != null);

                var db_transaction = dbm.start_transaction ();

                // update transaction
                dbm.update_transaction (transaction, ref db_transaction);

                // first cancel old transaction
                adjust_balance (transaction.account, current_transaction, true);

                // update account balance
                adjust_balance (transaction.account, transaction);

                dbm.update_account_balance (transaction.account, ref db_transaction);

                db_transaction.commit ();

                transaction_updated (transaction);
                account_updated (transaction.account);
            }
            catch (SQLHeavy.Error err) {
                transaction.account.balance = old_balance;
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Remove a transaction from the database, adjusting the affected account's balance
         */
        public void remove_transaction (ref Transaction transaction) throws ServiceError {

            try {
                var db_transaction = dbm.start_transaction ();

                dbm.delete_transaction (transaction.@id, ref db_transaction);

                adjust_balance (transaction.account, transaction, true);
                dbm.update_account_balance (transaction.account, ref db_transaction);

                db_transaction.commit ();

                if (transaction.account != null && transaction.account.transactions != null) {
                    transaction.account.transactions.remove (transaction);
                }

                transaction_deleted (transaction);
                account_updated (transaction.account);
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Imports transactions into this account. Will do its best to discard duplicates.
         */
        public int import_transactions_from_file (ref Account account, File file) throws ImporterError, ServiceError {

            var path = file.get_path ();

            if (!file.query_exists ()) {
                throw new ServiceError.ENOENT ("file does not exist: %s".printf (path));
            }

            var extension = path.substring (path.last_index_of (".") + 1).strip (); // eg. "qif"

            Importer importer;

            // TODO: CSV, OFX

            switch (extension.up ()) {
                case "QIF":
                    importer = QIFImporter.get_default ();
                    break;

                default:
                    throw new ImporterError.UNSUPPORTED ("file is of unknown format");
            }

            // we use this if something goes wrong with the database during import
            var balance_before_import = account.balance;

            try {
                var transactions = importer.import (path);

                if (transactions != null && !transactions.is_empty) {

                    double balance_delta = 0d;

                    foreach (Transaction t in transactions) {

                        switch (t.direction) {
                            case Transaction.Direction.INCOMING:
                                balance_delta += t.amount;
                                break;

                            case Transaction.Direction.OUTGOING:
                                balance_delta -= t.amount;
                                break;

                            default:
                                assert_not_reached ();
                        }

                        t.account = account;
                    }

                    info ("adjusting balance for account: %s (new balance: %s)".printf (Envelope.Util.String.format_currency (account.balance),
                        Envelope.Util.String.format_currency (account.balance + balance_delta)));

                    account.balance += balance_delta;

                    var db_transaction = dbm.start_transaction ();

                    dbm.insert_transactions (transactions, ref db_transaction);
                    dbm.update_account_balance (account, ref db_transaction);

                    db_transaction.commit ();

                    account.transactions.add_all (transactions);
                    account.transactions.sort ();

                    // fire signals
                    transactions_imported (transactions, account);
                    account_updated (account);

                    return transactions.size;
                }

                return 0;
            }
            catch (SQLHeavy.Error err) {
                account.balance = balance_before_import;
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
            catch (ImporterError err) {
                account.balance = balance_before_import;
                throw err;
            }
        }

        /**
         * Adjust an account's balance according to the transaction's amount and direction
         *
         * @param account the account to adjust the balance on
         * @param transaction the transaction used to calculate amounts
         * @param cancel if true, will invert the calculations to actually cancel a transaction
         * @return the new account's balance
         */
        private static double adjust_balance (Account account, Transaction transaction, bool cancel = false) {

            switch (transaction.direction) {

                case Transaction.Direction.INCOMING:

                    if (cancel) {
                        account.balance -= transaction.amount;
                    }
                    else {
                        account.balance += transaction.amount;
                    }

                    break;

                case Transaction.Direction.OUTGOING:

                    if (cancel) {
                        account.balance += transaction.amount;
                    }
                    else {
                        account.balance -= transaction.amount;
                    }

                    break;

                default:
                    assert_not_reached ();
            }

            return account.balance;
        }
    }

}
