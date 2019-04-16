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

namespace Envelope.Database {
    class DatabaseManager : Object {

        // get_int for null fields returns 0
        private const int NULL = 0;

        private const string DATABASE_FILENAME = "database.db";

        /**
         * An account was inserted in the database
         *
         * @param account the account which was inserted
         */
        public signal void account_created (Account account);

        /**
         * An account was removed from the database
         *
         * @param account the account which was removed
         */
        public signal void account_deleted (Account account);

        /**
         * An account was updated in the database
         *
         * @param account the account which was updated
         */
        public signal void accout_updated (Account account);

        /**
         * A category was inserted in the database
         *
         * @param category the category which was inserted
         */
        public signal void category_created (Category category);

        /**
         * A transaction was inserted in the database
         *
         * @param transaction the transaction which was inserted
         */
        public signal void transaction_created (Transaction transaction);

        // singleton instance
        private static DatabaseManager database_manager_instance = null;

        // database handler
        private Database database;

        // in-memory caches for often-used objects
        //private SortedMap<int, Account> account_cache = new TreeMap<int, Account> ();
        private SortedMap<string, Category> category_cache = new TreeMap<string, Category> ();
        private SortedMap<string, Payee> payee_cache = new TreeMap<string, Payee> ();

        /**
         * Obtain a reference to the singleton instance of the DatabaseManager
         *
         * @return the DatabaseManager singleton instance
         */
        public static new DatabaseManager get_default () {
            if (database_manager_instance == null) {
                database_manager_instance = new DatabaseManager ();
            }

            return database_manager_instance;
        }

        /**
         * Start a database transaction.
         */
        public void start_transaction () throws DatabaseError {
            this.database.begin ();
        }

        /**
         * Commit a database transaction.
         */
        public void commit_transaction () throws DatabaseError {
            this.database.commit ();
        }

        /**
         * Rollback a database transaction.
         */
        public void rollback_transaction () throws DatabaseError {
            this.database.rollback ();
        }

        /**
         * Get the list of all payees
         *
         * @return list of unique payees
         */
        public Collection<Payee> get_payees () throws DatabaseError {
            if (!payee_cache.is_empty) {
                return payee_cache.values;
            }

            var cursor = this.database.exec_cursor (SQL_GET_UNIQUE_MERCHANTS);
            foreach (var stmt in cursor) {
                Payee payee;
                var label = stmt.column_text (0);
                var count = stmt.column_int (1);

                payee = new Payee (label, count);
                payee_cache.@set (payee.label, payee);
            }

            debug ("%d unique payees", payee_cache.size);

            return payee_cache.values;
        }

        /**
         * Fetch the account having the specified id
         *
         * @param account_id the id of the account to load
         * @return the Account object having the specified id, or null if not found
         * @throws DatabaseError
         */
        public Account? load_account (int account_id) throws DatabaseError {
            // if (account_cache.has_key (account_id)) {
            //     return account_cache.@get (account_id);
            // }
            //

            GLib.Value[] args = { account_id };
            var cursor = this.database.exec_cursor (SQL_LOAD_ACCOUNT_BY_ID, args);
            foreach (var stmt in cursor) {
                Account account;
                query_result_to_account (stmt, out account);

                // account_cache.@set (account.@id, account);

                return account;
            }

            return null;
        }

        /**
         * Delete an account from the database.
         *
         * @param account the account to delete
         * @throws SQLHeavy.Error
         */
        public void delete_account (Account account) throws DatabaseError {
            GLib.Value[] args = { (int) account.@id };
            this.database.exec (SQL_DELETE_ACCOUNT, args);

            // delete from cache
            // if (account_cache.has_key (account.@id)) {
            //     account_cache.unset (account.@id);
            // }
        }

        /**
         * Load all accounts from the database
         *
         * @return the list of accounts
         */
        public Collection<Account> load_all_accounts () throws DatabaseError {
            // if (!account_cache.is_empty) {
            //     message ("LOAD RETURNED");
            //     return account_cache.values;
            // }

            var list = new TreeSet<Account> ();

            var cursor = this.database.exec_cursor (SQL_LOAD_ALL_ACCOUNTS);
            foreach (var stmt in cursor) {
                Account account;
                query_result_to_account (stmt, out account);

                list.add (account);

                //TODO add to cache too
                //account_cache.@set (account.@id, account);
            }

            return list;
        }

        /**
         * Create a new category
         *
         * @param category the category to save
         * @throws SQLHeavy.Error
         */
        public void create_category (Category category) throws DatabaseError {
            GLib.Value[] args = {
                category.name,
                category.description != null ? category.description : @null (),
                category.parent != null ? (int) category.parent.@id : @null ()
            };

            this.database.exec (SQL_INSERT_CATEGORY, args);

            var id = this.database.last_insert_rowid ();

            category.@id = (int) id;

            // add to cache
            category_cache.@set (category.name.up (), category);

            category_created (category);
        }

        /**
         * Update a category
         *
         * @param category the category to update
         */
        public void update_category (Category category) throws DatabaseError {
            GLib.Value[] args = {
                category.name,
                category.description,
                category.parent != null ? (int) category.parent.@id : @null (),
                (int) category.@id
            };

            this.database.exec (SQL_UPDATE_CATEGORY, args);

            category_cache.@set (category.name.up (), category);
        }

        public void set_category_budgeted_amount (MonthlyCategory category, int year, int month) throws DatabaseError {
            GLib.Value[] args = {(int) category.@id, year, month};

            int size = this.database.query_value (SQL_CHECK_CATEGORY_BUDGET_SET, args);

            if (size == 0) {
                GLib.Value[] args2 = {(int) category.@id, year, month, category.amount_budgeted};
                this.database.exec (SQL_SET_CATEGORY_BUDGET, args2);
            } else {
                update_category_budgeted_amount (category, year, month);
            }
        }

        public void update_category_budgeted_amount (MonthlyCategory category, int year, int month) throws DatabaseError {
            GLib.Value[] args = {category.amount_budgeted, (int) category.@id, year, month};
            this.database.exec (SQL_UPDATE_CATEGORY_BUDGET, args);
        }

        /**
         * Assign all transactions having the specified payee to a category
         *
         * @param payee the name of the payee to match
         * @param category the category to assign to each transaction
         * @throws SQLHeavy.Error
         */
        public void categorize_for_payee (string payee, Category category) throws DatabaseError {
            GLib.Value[] args = {(int) category.@id, payee};
            this.database.exec (SQL_CATEGORIZE_ALL_FOR_MERCHANT, args);
        }

        /**
         * Create a new account
         *
         * @param account the account to create
         * @throws SQLHeavy.Error
         */
        public void create_account (Account account) throws DatabaseError {
            GLib.Value[] args = {account.number, account.description, account.balance, (int) account.account_type};
            this.database.exec (SQL_INSERT_ACCOUNT, args);

            account.@id = (int) this.database.last_insert_rowid ();

            // account_cache.@set (account.@id, account);

            account_created (account);
        }

        /**
         * Rename an account
         *
         * @param account the account to rename
         * @param new_name the new name to assign
         * @throws SQLHeavy.Error
         */
        public void rename_account (Account account, string new_name) throws DatabaseError {
            GLib.Value[] args = {new_name, (int) account.@id};
            this.database.exec (SQL_RENAME_ACCOUNT, args);

            // update cache
            // account_cache.@set (account.@id, account);
        }

        /**
         * Update the account's balance in the database
         *
         * @param account the account to update
         * @param transaction the database transaction to use
         * @throws SQLHeavy.Error
         */
        public void update_account_balance (Account account) throws DatabaseError {
            GLib.Value[] args = {account.balance, (int) account.@id};
            this.database.exec (SQL_UPDATE_ACCOUNT_BALANCE, args);

            // update cache
            // account_cache.@set (account.@id, account);
        }

        /**
         * Load transactions for the specified account
         *
         * @param account the account to load transactions from
         * @return the list of transactions for this account
         * @throws DatabaseError
         */
        public Gee.List<Transaction> load_account_transactions (Account account) throws DatabaseError {
            var list = new ArrayList<Transaction> ();

            GLib.Value[] args = {(int) account.@id};
            var cursor = this.database.exec_cursor (SQL_LOAD_ACCOUNT_TRANSACTIONS, args);
            foreach (var stmt in cursor) {
                Transaction transaction;

                query_result_to_transaction (stmt, out transaction);

                transaction.account = account;
                list.add (transaction);
            }

            return list;
        }

        /**
         * Load all transactions not associated to a category
         *
         * @return the list of uncategorized transactions
         * @throws DatabaseError
         */
        public Collection<Transaction> load_uncategorized_transactions () throws DatabaseError {
            var list = new ArrayList<Transaction> ();

            var cursor = this.database.exec_cursor (SQL_GET_UNCATEGORIZED_TRANSACTIONS);
            foreach (var results in cursor) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                list.add (transaction);
            }

            return list;
        }

        public void insert_transaction (Transaction transaction) throws DatabaseError {
            GLib.Value[8] args = {
                transaction.label,
                transaction.description,
                transaction.amount,
                (int) transaction.direction,
                (int) transaction.account.@id,
                transaction.parent != null ? (int) transaction.parent.@id : @null (),
                (int) transaction.date.to_unix (),
                transaction.category != null ? (int) transaction.category.@id : @null ()
            };
            try {
                this.database.exec (SQL_INSERT_TRANSACTION, args);
            } catch (DatabaseError e) {
                print ("ERROR HERE " + e.message);
            }

            int id = (int) this.database.last_insert_rowid ();

            debug ("transaction created with id %d".printf (id));

            transaction.@id = id;

            transaction_created (transaction);
        }

        /**
         * Insert multiple transactions
         */
        public void insert_transactions (Collection<Transaction> transactions) throws DatabaseError {
            // TODO bulk insert
            foreach (Transaction t in transactions) {
                insert_transaction (t);
            }
        }

        public void delete_transaction (int transaction_id) throws DatabaseError {
            GLib.Value[] args = {transaction_id};
            this.database.exec (SQL_DELETE_TRANSACTION, args);
        }


        public void update_transaction (Transaction transaction) throws DatabaseError {
            GLib.Value[9] args = {
                transaction.label,
                transaction.description,
                (int) transaction.direction,
                transaction.amount,
                (int) transaction.account.@id,
                transaction.category != null ? (int) transaction.category.@id : @null (),
                transaction.parent != null ? (int) transaction.parent.@id : @null (),
                (int) transaction.date.to_unix (),
                (int) transaction.@id
            };

            this.database.exec (SQL_UPDATE_TRANSACTION, args);
        }

        public Transaction? get_transaction_by_id (int id) throws DatabaseError {
            GLib.Value[] args = { id };
            var results = this.database.exec_cursor (SQL_GET_TRANSACTION_BY_ID, args);

            foreach (var stmt in results) {
                Transaction transaction;
                query_result_to_transaction (stmt, out transaction);

                return transaction;
            }

            return null;
        }

        public Collection<MonthlyCategory> load_categories () throws DatabaseError {
            if (!category_cache.is_empty) {
                return category_cache.values as Collection<MonthlyCategory>;
            }

            var list = new TreeSet<MonthlyCategory> ();

            var results = this.database.exec_cursor (SQL_LOAD_CATEGORIES);

            foreach (var stmt in results) {
                MonthlyCategory category;
                int parent_id;

                query_result_to_category (stmt, out category, out parent_id);

                // TODO add to parent ???

                list.add (category);

                // add to cache too
                category_cache.@set (category.name.up (), category);
            }

            return list;
        }

        public Collection<Transaction> get_current_transactions () throws DatabaseError {
            int month, year;
            Envelope.Util.Date.get_year_month (out month, out year);

            return get_transactions_for_month_and_year (month, year);
        }

        public Collection<Transaction> get_transactions_for_month_and_year (int month, int year) throws DatabaseError {
            var list = new ArrayList<Transaction> ();

            GLib.Value[] args = {year, month, "%4d-%02d-01".printf (year, month), "%4d-%02d-01".printf (year, month) };

            var results = this.database.exec_cursor (SQL_LOAD_TRANSACTIONS_FOR_MONTH, args);

            foreach (var stmt in results) {
                Transaction transaction;
                query_result_to_transaction (stmt, out transaction);

                MonthlyCategory category;
                int parent_category_id;
                query_result_to_category (stmt, out category, out parent_category_id);

                transaction.category = category.@id != NULL ? category : null;

                list.add (transaction);
            }

            return list;
        }

        public Gee.List<Transaction> get_current_transactions_for_category (Category? category) throws DatabaseError {
            var list = new ArrayList<Transaction> ();

            Cursor cur;

            if (category != null) {
                GLib.Value[] args = { (int) category.@id };
                cur = this.database.exec_cursor (SQL_LOAD_CURRENT_TRANSACTIONS_FOR_CATEGORY, args);
            } else {
                cur = this.database.exec_cursor (SQL_LOAD_CURRENT_UNCATEGORIZED_TRANSACTIONS);
            }

            foreach (var stmt in cur) {
                Transaction transaction;
                query_result_to_transaction (stmt, out transaction, category);

                list.add (transaction);
            }

            return list;
        }

        public void delete_category (Category category) throws DatabaseError {
            // no need to update transactions; ON DELETE SET NULL
            debug ("Deleting Category %d - %s", (int) category.@id, category.name);
            GLib.Value[] args = { (int) category.@id };
            this.database.exec (SQL_DELETE_CATEOGRY, args);

            // remove from cache
            category_cache.unset (category.name.up ());
        }

        private DatabaseManager () {
            Object ();
            init ();
            connect_signals ();
        }

        private void init () {
            int version = 0;
            try {
                database = new Database ("envelope.db");
                this.database.exec ("PRAGMA synchronous = OFF;");
                version = this.database.query_value ("PRAGMA user_version;");
                info ("DATABASE_USER_VERSION: %d", version);
            } catch (DatabaseError e) {
                error ("SQLITE_ERROR: %d - %s", e.code, e.message);
            }

            switch (version) {
                case 0: // original version
                    break;
                case 1:
                    update_database_schema_v1 ();
                    break;
            }

            try {
                this.start_transaction ();
                this.database.exec (TRANSACTIONS);
                this.database.exec (ACCOUNTS);
                this.database.exec (CATEGORIES);
                this.database.exec (MONTHLY_CATEGORIES);
                this.database.exec (MONTHLY_BUDGET);
                this.commit_transaction ();
            } catch (DatabaseError e) {
                error ("error occured during database setup (%s)", e.message);
            }

            // check if there are categories. If not, then create the default ones
            try {
                check_create_categories ();
                this.database.exec ("PRAGMA foreign_keys = ON;");
            } catch (DatabaseError err) {
                error ("could not initialize default categories (%s)".printf (err.message));
            }
        }

        private void check_create_categories () throws DatabaseError {
            // check if there are categories. If not, then create the default ones
            if (this.database.query_value (SQL_CATEGORY_COUNT) == 0) {
                try {
                    this.start_transaction ();

                    var default_categories = new string[] {
                        _("Groceries"),
                        _("Fuel"),
                        _("Public transit"),
                        _("Restaurants"),
                        _("Entertainment"),
                        _("Savings"),
                        _("Personal care"),
                        _("Alcohol & Bars"),
                        _("Emergency fund")
                    };

                    foreach (string name in default_categories) {
                        GLib.Value[] args = { name };
                        this.database.exec (SQL_INSERT_CATEGORY_FOR_NAME, args);
                    }

                    this.commit_transaction ();
                } catch (DatabaseError e) {
                    warning ("Failed to create default categories: %s", e.message);
                }
            }
        }

        private void update_database_schema_v1 () {

        }

        private void query_result_to_account (Sqlite.Statement results, out Account account) throws DatabaseError {
            int cols = results.column_count ();
            account = new Account ();

            for (int i = 0; i < cols; i++) {
                switch (results.column_name (i)) {
                    case "id":
                        account.@id = results.column_int (i);
                        break;
                    case "number":
                        account.number = results.column_text (i);
                        break;
                    case "description":
                        account.description = results.column_text (i);
                        break;
                    case "balance":
                        account.balance = results.column_double (i);
                        break;
                    case "type":
                        account.account_type = Account.Type.from_int (results.column_int (i));
                        break;
                }
            }
        }

        private void query_result_to_transaction (Sqlite.Statement results, out Transaction transaction, Category? category = null) throws DatabaseError {
            int cols = results.column_count ();
            int category_id = 0;
            transaction = new Transaction ();

            for (int i = 0; i < cols; i++) {
                switch (results.column_name (i)) {
                    case "id":
                        transaction.@id = results.column_int (i);
                        break;
                    case "label":
                        transaction.label = results.column_text (i);
                        break;
                    case "description":
                        transaction.description = results.column_text (i);
                        break;
                    case "direction":
                        transaction.direction = Transaction.Direction.from_int (results.column_int (i));
                        break;
                    case "amount":
                        transaction.amount = results.column_double (i);
                        break;
                    case "date":
                        transaction.date = new DateTime.from_unix_local (results.column_int64 (i));
                        break;
                    case "category_id":
                        category_id = results.column_int (i);
                        break;
                    case "account_id":
                        transaction.account = load_account (results.column_int (i));
                        break;
                }
            }

            if (category != null) {
                transaction.category = category;
            } else if (category_id != 0) {
                transaction.category = Envelope.Service.CategoryStore.get_default ().get_category_by_id (category_id);
            }
        }

        private void query_result_to_category (Sqlite.Statement results, out MonthlyCategory category, out int parent_id) throws DatabaseError {
            int cols = results.column_count ();
            category = new MonthlyCategory ();

            for (int i = 0; i < cols; i++) {
                switch (results.column_name (i)) {
                    case "id":
                        category.@id = results.column_int (i);
                        break;
                    case "name":
                        category.name = results.column_text (i);
                        break;
                    case "description":
                        category.description = results.column_text (i);
                        break;
                    case "amount_budgeted":
                        category.amount_budgeted = results.column_double (i);
                        break;
                    case "year":
                        category.year = results.column_int (i);
                        break;
                    case "month":
                        category.month = results.column_int (i);
                        break;
                    case "parent_category_id":
                        // parent_id is sent to caller to select parent if needed
                        parent_id = results.column_int (i);
                        break;
                }
            }
        }

        private void connect_signals () {
            // invalidate payee cache when a transaction is recorded
            transaction_created.connect ((transaction) => {
                payee_cache.clear ();
            });
        }

        private void debug_sql (string sql) {
            debug ("SQLITE: %s", sql.strip ());
        }
    }
}
