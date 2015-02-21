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

namespace Envelope.DB {

    class DatabaseManager : Object {

        // get_int for null fields returns 0
        private static const int NULL = 0;

        private static const string DATABASE_FILENAME = "database.db";

        private static const string ACCOUNTS = """
            CREATE TABLE IF NOT EXISTS accounts (
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,
                `number` TEXT NOT NULL,
                `description` TEXT,
                `balance` DOUBLE,
                `type` INT)
            """;

        private static const string TRANSACTIONS = """
            CREATE TABLE IF NOT EXISTS transactions (
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,
                `label` TEXT NOT NULL,
                `description` TEXT,
                `direction` INT NOT NULL,
                `amount` DOUBLE NOT NULL,
                `account_id` INT NOT NULL,
                `category_id` INT,
                `parent_transaction_id` INT,
                `date` TIMESTAMP NOT NULL,
            FOREIGN KEY (`parent_transaction_id`) REFERENCES `transactions`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
            FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON UPDATE CASCADE ON DELETE SET NULL,
            FOREIGN KEY (`account_id`) REFERENCES `accounts`(`id`) ON UPDATE CASCADE ON DELETE CASCADE)
            """;

        private static const string CATEGORIES = """
            CREATE TABLE IF NOT EXISTS categories (
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,
                `name` TEXT NOT NULL,
                `description` TEXT,
                `parent_category_id` INT,
            FOREIGN KEY (`parent_category_id`) REFERENCES `categories`(`id`) ON UPDATE CASCADE ON DELETE CASCADE)
            """;

        private static const string MONTHLY_CATEGORIES = """
            CREATE TABLE IF NOT EXISTS categories_budgets (
                `category_id` INTEGER NOT NULL,
                `year` INTEGER NOT NULL,
                `month` INTEGER NOT NULL,
                `amount_budgeted` DOUBLE,
            PRIMARY KEY (`category_id`, `year`, `month`),
            FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
            ) WITHOUT ROWID
        """;

        private static const string MONTHLY_BUDGET = """
            CREATE TABLE IF NOT EXISTS monthly_budgets (
                `month` INTEGER NOT NULL,
                `year` INTEGER NOT NULL,
                `outflow` DOUBLE,
                `inflow` DOUBLE,
            PRIMARY KEY (`month`, `year`)
            ) WITHOUT ROWID
        """;

        private static const string SQL_CATEGORY_COUNT = "SELECT COUNT(*) AS category_count from categories";
        private static const string SQL_INSERT_CATEGORY_FOR_NAME = "INSERT INTO `categories` (`name`) VALUES (:name);";
        private static const string SQL_SET_CATEGORY_BUDGET = "INSERT INTO `categories_budgets` (`category_id`, `year`, `month`, `amount_budgeted`) VALUES (:category_id, :year, :month, :amount_budgeted)";
        private static const string SQL_UPDATE_CATEGORY_BUDGET = "UPDATE `categories_budgets` SET `amount_budgeted` = :amount_budgeted WHERE `category_id` = :category_id AND `year` = :year AND `month` = :month";
        private static const string SQL_CHECK_CATEGORY_BUDGET_SET = "SELECT COUNT(*) AS size FROM categories_budgets WHERE category_id = :category_id AND year = :year AND month = :month";
        private static const string SQL_DELETE_TRANSACTION = "DELETE FROM `transactions` WHERE `id` = :id";
        private static const string SQL_GET_TRANSACTION_BY_ID = "SELECT * FROM `transactions` WHERE `id` = :id";
        private static const string SQL_GET_UNCATEGORIZED_TRANSACTIONS = "SELECT * FROM `transactions` WHERE `category_id` IS NULL";
        private static const string SQL_RENAME_ACCOUNT = "UPDATE `accounts` SET `number` = :number WHERE `id` = :account_id";
        private static const string SQL_DELETE_ACCOUNT = "DELETE FROM `accounts` WHERE `id` = :account_id";
        private static const string SQL_UPDATE_ACCOUNT_BALANCE = "UPDATE `accounts` SET `balance` = :balance WHERE `id` = :account_id";
        private static const string SQL_LOAD_ACCOUNT_TRANSACTIONS = "SELECT * FROM `transactions` WHERE `account_id` = :account_id ORDER BY `date` DESC";
        private static const string SQL_DELETE_ACCOUNT_TRANSACTIONS = "DELETE FROM `transactions` WHERE `account_id` = :account_id";
        private static const string SQL_GET_UNIQUE_MERCHANTS = "SELECT `label`, COUNT(`label`) as `number` FROM `transactions` GROUP BY `label` ORDER BY `number` DESC, `label` ASC";
        private static const string SQL_LOAD_CATEGORIES = "SELECT `c`.*, `cb`.`year`, `cb`.`month`, `cb`.`amount_budgeted` FROM `categories` `c` LEFT JOIN `categories_budgets` `cb` ON `cb`.`category_id` = `c`.`id` AND `cb`.`year` = strftime('%Y', 'now') AND `cb`.`month` = strftime('%m', 'now') ORDER BY `c`.`name` ASC";
        private static const string SQL_LOAD_CHILD_CATEGORIES = "SELECT * FROM `categories` WHERE `parent_category_id` = :parent_category_id ORDER BY `name` ASC";
        private static const string SQL_DELETE_CATEOGRY = "DELETE FROM `categories` WHERE `id` = :category_id";
        private static const string SQL_UPDATE_CATEGORY = "UPDATE `categories` SET `name` = :name, `description` = :description, `parent_category_id` = :parent_category_id WHERE `id` = :category_id";
        private static const string SQL_CATEGORIZE_ALL_FOR_MERCHANT = "UPDATE `transactions` SET `category_id` = :category_id WHERE `label` = :merchant";
        private static const string SQL_LOAD_CURRENT_TRANSACTIONS = "SELECT * FROM transactions WHERE date(date, 'unixepoch') BETWEEN date('now', 'start of month') AND date('now', 'start of month', '+1 month', '-1 days')";

        private static const string SQL_LOAD_TRANSACTIONS_FOR_MONTH = """SELECT t.*, c.*, cb.* FROM transactions t
            LEFT JOIN categories c
            ON c.id = t.category_id
            LEFT JOIN categories_budgets cb
            ON cb.category_id = t.category_id AND cb.year = :year and cb.month = :month
            WHERE date(t.date, 'unixepoch') BETWEEN date(:date, 'start of month') AND date(:date, 'start of month', '+1 month', '-1 days')
            ORDER BY t.date DESC""";

        private static const string SQL_LOAD_CURRENT_TRANSACTIONS_FOR_CATEGORY = "SELECT * FROM transactions WHERE date(date, 'unixepoch') BETWEEN date('now', 'start of month') and date('now', 'start of month', '+1 month', '-1 days') AND category_id = :category_id";
        private static const string SQL_LOAD_CURRENT_UNCATEGORIZED_TRANSACTIONS = "SELECT * FROM transactions WHERE date(date, 'unixepoch') BETWEEN date('now', 'start of month') and date('now', 'start of month', '+1 month', '-1 days') AND category_id IS NULL";

        private static const string SQL_INSERT_CATEGORY = """INSERT INTO `categories`
            (`name`, `description`, `parent_category_id`)
            VALUES
            (:name, :description, :parent_category_id)
        """;

        private static const string SQL_UPDATE_TRANSACTION = """UPDATE `transactions` SET
            label = :label,
            description = :description,
            direction = :direction,
            amount = :amount,
            account_id = :account_id,
            category_id = :category_id,
            parent_transaction_id = :parent_transaction_id,
            date = :date
            WHERE id = :transaction_id
        """;

        private static const string SQL_INSERT_TRANSACTION = """
            INSERT INTO `transactions`
            (`label`, `description`, `amount`, `direction`, `account_id`, `parent_transaction_id`, `date`, `category_id`)
            VALUES
            (:label, :description, :amount, :direction, :account_id, :parent_transaction_id, :date, :category_id)
        """;

        private static const string SQL_LOAD_ACCOUNT_BY_ID = "SELECT * FROM `accounts` WHERE `id` = :accountid;";
        private static const string SQL_LOAD_ALL_ACCOUNTS = "SELECT * FROM `accounts` ORDER BY `number`;";
        private static const string SQL_INSERT_ACCOUNT = """
            INSERT INTO `accounts`
            (`number`, `description`, `balance`, `type`)
            VALUES
            (:number, :description, :balance, :type);
            """;

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
        private SQLHeavy.Database database;

        // prepared statements
        private SQLHeavy.Query q_load_account;
        private SQLHeavy.Query q_load_all_accounts;
        private SQLHeavy.Query q_insert_account;
        private SQLHeavy.Query q_rename_account;
        private SQLHeavy.Query q_delete_account;
        private SQLHeavy.Query q_update_account_balance;

        private SQLHeavy.Query q_load_account_transactions;
        private SQLHeavy.Query q_delete_account_transactions;
        private SQLHeavy.Query q_insert_account_transaction;
        private SQLHeavy.Query q_delete_transaction;
        private SQLHeavy.Query q_load_uncategorized_transactions;
        private SQLHeavy.Query q_categorize_for_merchant;
        private SQLHeavy.Query q_load_transactions_for_month_and_year;

        private SQLHeavy.Query q_load_current_transactions;
        private SQLHeavy.Query q_load_current_transactions_for_category;
        private SQLHeavy.Query q_load_current_uncategorized_transactions;

        private SQLHeavy.Query q_get_unique_merchants;

        private SQLHeavy.Query q_load_categories;
        private SQLHeavy.Query q_load_child_categories;
        private SQLHeavy.Query q_insert_category;
        private SQLHeavy.Query q_delete_category;
        private SQLHeavy.Query q_update_category;
        private SQLHeavy.Query q_update_category_budgeted_amount;
        private SQLHeavy.Query q_set_category_budgeted_amount;
        private SQLHeavy.Query q_check_category_budget_set;

        // in-memory caches for often-used objects
        private SortedMap<int, Account>           account_cache     = new TreeMap<int, Account> ();
        private SortedMap<string, Category>       category_cache    = new TreeMap<string, Category> ();
        private SortedMap<string, Merchant>       merchant_cache    = new TreeMap<string, Merchant> ();

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
         *
         * @return the transaction instance
         */
        public SQLHeavy.Transaction start_transaction () throws SQLHeavy.Error {
            return database.begin_transaction ();
        }

        /**
         * Get the list of all merchants
         *
         * @return list of unique merchants
         */
        public Collection<Merchant> get_merchants () throws SQLHeavy.Error {

            if (!merchant_cache.is_empty) {
                return merchant_cache.values;
            }

            var merchants = new TreeSet<Merchant> ();

            SQLHeavy.QueryResult results = q_get_unique_merchants.execute ();

            while (!results.finished) {
                Merchant merchant;
                query_result_to_merchant (results, out merchant);

                merchants.add (merchant);

                // add to cache too
                merchant_cache.@set (merchant.label, merchant);

                results.next ();
            }

            debug ("%d unique merchants", merchants.size);

            return merchants;
        }

        /**
         * Fetch the account having the specified id
         *
         * @param account_id the id of the account to load
         * @return the Account object having the specified id, or null if not found
         * @throws SQLHeavy.Error
         */
        public Account? load_account (int account_id) throws SQLHeavy.Error {

            if (account_cache.has_key (account_id)) {
                return account_cache.@get (account_id);
            }

            q_load_account.set_int ("accountid", account_id);

            SQLHeavy.QueryResult results = q_load_account.execute ();

            if (!results.finished) {

                Account account;
                query_result_to_account (results, out account);
                q_load_account.clear ();

                account_cache.@set (account.@id, account);

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
        public void delete_account (Account account) throws SQLHeavy.Error {

            q_delete_account.set_int ("account_id", account.@id);
            q_delete_account.execute ();
            q_delete_account.clear ();

            // delete from cache
            if (account_cache.has_key (account.@id)) {
                account_cache.unset (account.@id);
            }
        }

        /**
         * Load all accounts from the database
         *
         * @return the list of accounts
         */
        public Collection<Account> load_all_accounts () throws SQLHeavy.Error {

            if (!account_cache.is_empty) {
                return account_cache.values;
            }

            var list = new TreeSet<Account> ();

            SQLHeavy.QueryResult results = q_load_all_accounts.execute ();

            while (!results.finished) {

                Account account;
                query_result_to_account (results, out account);

                list.add (account);

                // add to cache too
                account_cache.@set (account.@id, account);

                results.next ();
            }

            return list;
        }

        /**
         * Create a new category
         *
         * @param category the category to save
         * @throws SQLHeavy.Error
         */
        public void create_category (Category category) throws SQLHeavy.Error {

            q_insert_category.set_string ("name", category.name);

            if (category.description != null) {
                q_insert_category.set_string ("description", category.description);
            }
            else {
                q_insert_category.set_null ("description");
            }

            if (category.parent != null) {
                q_insert_category.set_int ("parent_category_id", category.parent.@id);
            }
            else {
                q_insert_category.set_null ("parent_category_id");
            }

            var id = q_insert_category.execute_insert ();

            q_insert_category.clear ();

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
        public void update_category (Category category) throws SQLHeavy.Error {

            q_update_category.set_int ("category_id", category.@id);
            q_update_category.set_string ("name", category.name);
            q_update_category.set_string ("description", category.description);
            //q_update_category.set_double ("amount_budgeted", category.amount_budgeted);

            if (category.parent != null) {
                q_update_category.set_int ("parent_category_id", category.parent.@id);
            }
            else {
                q_update_category.set_null ("parent_category_id");
            }

            q_update_category.execute ();
            q_update_category.clear ();

            category_cache.@set (category.name.up (), category);
        }

        public void set_category_budgeted_amount (MonthlyCategory category, int year, int month) throws SQLHeavy.Error {

            q_check_category_budget_set.set_int ("category_id", category.@id);
            q_check_category_budget_set.set_int ("year", year);
            q_check_category_budget_set.set_int ("month", month);

            SQLHeavy.QueryResult results = q_check_category_budget_set.execute ();

            q_check_category_budget_set.clear ();

            int size = results.get_int ("size");

            if (size == 0) {
                q_set_category_budgeted_amount.set_int ("category_id", category.@id);
                q_set_category_budgeted_amount.set_int ("year", year);
                q_set_category_budgeted_amount.set_int ("month", month);
                q_set_category_budgeted_amount.set_double ("amount_budgeted", category.amount_budgeted);
                q_set_category_budgeted_amount.execute ();
                q_set_category_budgeted_amount.clear ();
            }
            else {
                update_category_budgeted_amount (category, year, month);
            }
        }

        public void update_category_budgeted_amount (MonthlyCategory category, int year, int month) throws SQLHeavy.Error {

            q_update_category_budgeted_amount.set_int ("category_id", category.@id);
            q_update_category_budgeted_amount.set_double ("amount_budgeted", category.amount_budgeted);
            q_update_category_budgeted_amount.set_int ("year", year);
            q_update_category_budgeted_amount.set_int ("month", month);

            q_update_category_budgeted_amount.execute ();
            q_update_category_budgeted_amount.clear ();
        }

        /**
         * Assign all transactions having the specified merchant to a category
         *
         * @param merchant the name of the merchant to match
         * @param category the category to assign to each transaction
         * @throws SQLHeavy.Error
         */
        public void categorize_for_merchant (string merchant, Category category) throws SQLHeavy.Error {
            q_categorize_for_merchant.set_string ("merchant", merchant);
            q_categorize_for_merchant.set_int ("category_id", category.@id);
            q_categorize_for_merchant.execute ();
            q_categorize_for_merchant.clear ();
        }

        /**
         * Create a new account
         *
         * @param account the account to create
         * @throws SQLHeavy.Error
         */
        public void create_account (Account account) throws SQLHeavy.Error {

            var id = q_insert_account.execute_insert (
                "number", typeof (string), account.number,
                "description", typeof (string), account.description,
                "balance", typeof (double), account.balance,
                "type", typeof (int), (int) account.account_type
                );

            account.@id = (int) id;

            account_cache.@set (account.@id, account);

            account_created (account);
        }

        /**
         * Rename an account
         *
         * @param account the account to rename
         * @param new_name the new name to assign
         * @throws SQLHeavy.Error
         */
        public void rename_account (Account account, string new_name) throws SQLHeavy.Error {
            q_rename_account.set_int ("account_id", account.@id);
            q_rename_account.set_string ("number", new_name);
            q_rename_account.execute ();
            q_rename_account.clear ();

            // update cache
            account_cache.@set (account.@id, account);
        }

        /**
         * Update the account's balance in the database
         *
         * @param account the account to update
         * @param transaction the database transaction to use
         * @throws SQLHeavy.Error
         */
        public void update_account_balance (Account account, ref SQLHeavy.Transaction transaction)  throws SQLHeavy.Error {
            transaction
                .prepare (SQL_UPDATE_ACCOUNT_BALANCE)
                .execute ("balance", typeof (double), account.balance, "account_id", typeof (int), account.@id);

            // update cache
            account_cache.@set (account.@id, account);
        }

        /**
         * Load transactions for the specified account
         *
         * @param account the account to load transactions from
         * @return the list of transactions for this account
         * @throws SQLHeavy.Error
         */
        public Gee.List<Transaction> load_account_transactions (Account account) throws SQLHeavy.Error {

            var list = new ArrayList<Transaction> ();

            q_load_account_transactions.set_int ("account_id", account.@id);

            SQLHeavy.QueryResult results = q_load_account_transactions.execute ();

            while (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                transaction.account = account;
                list.add (transaction);

                results.next ();
            }

            q_load_account_transactions.clear ();

            return list;
        }

        /**
         * Load all transactions not associated to a category
         *
         * @return the list of uncategorized transactions
         * @throws SQLHeavy.Error
         */
        public Collection<Transaction> load_uncategorized_transactions () throws SQLHeavy.Error {

            var list = new ArrayList<Transaction> ();

            SQLHeavy.QueryResult results = q_load_uncategorized_transactions.execute ();

            while (!results.finished) {

                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                list.add (transaction);

                results.next ();
            }

            return list;
        }

        public void insert_transaction (Transaction transaction, ref SQLHeavy.Transaction db_transaction, SQLHeavy.Query? statement = null) throws SQLHeavy.Error {

            var q = statement != null ? statement : db_transaction.prepare(SQL_INSERT_TRANSACTION);

            // optional category id
            if (transaction.category != null) {
                q.set_int ("category_id", transaction.category.@id);
            }
            else {
                q.set_null ("category_id");
            }

            // optional parent transaction id
            if (transaction.parent != null) {
                q.set_int ("parent_transaction_id", transaction.parent.@id);
            }
            else {
                q.set_null ("parent_transaction_id");
            }

            var id = q.execute_insert (
                "label", typeof (string), transaction.label,
                "description", typeof (string), transaction.description,
                "amount", typeof (double), transaction.amount,
                "direction", typeof (int), (int) transaction.direction,
                "account_id", typeof (int), transaction.account.@id,
                "date", typeof (int), (int) transaction.date.to_unix ()
            );

            debug ("transaction created with id %d".printf ((int) id));

            transaction.@id = (int) id;

            transaction_created (transaction);
        }

        /**
         * Insert multiple transactions
         */
        public void insert_transactions (Collection<Transaction> transactions, ref SQLHeavy.Transaction db_transaction) throws SQLHeavy.Error {

            var stmt = db_transaction.prepare (SQL_INSERT_TRANSACTION);

            // TODO bulk insert
            foreach (Transaction t in transactions) {
                insert_transaction (t, ref db_transaction, stmt);
            }
        }

        public void delete_transaction (int transaction_id, ref SQLHeavy.Transaction db_transaction) throws SQLHeavy.Error {

            var stmt = db_transaction.prepare (SQL_DELETE_TRANSACTION);
            stmt.set_int ("id", transaction_id);

            stmt.execute ();
        }


        public void update_transaction (Transaction transaction, ref SQLHeavy.Transaction db_transaction) throws SQLHeavy.Error {

            var stmt = db_transaction.prepare (SQL_UPDATE_TRANSACTION);

            // required fields
            stmt.set_int ("transaction_id", transaction.@id);
            stmt.set_string ("label", transaction.label);
            stmt.set_string ("description", transaction.description);
            stmt.set_int ("direction", (int) transaction.direction);
            stmt.set_double ("amount", transaction.amount);
            stmt.set_int ("account_id", transaction.account.@id);
            stmt.set_int ("date", (int) transaction.date.to_unix ());

            // optional fields
            if (transaction.category != null) {
                stmt.set_int ("category_id", transaction.category.@id);
            }
            else {
                stmt.set_null ("category_id");
            }

            if (transaction.parent != null) {
                stmt.set_int ("parent_transaction_id", transaction.parent.@id);
            }
            else {
                stmt.set_null ("parent_transaction_id");
            }

            stmt.execute ();
        }

        public Transaction? get_transaction_by_id (int id) throws SQLHeavy.Error {

            // TODO make statement global
            var stmt = database.prepare (SQL_GET_TRANSACTION_BY_ID);
            stmt.set_int ("id", id);

            var results = stmt.execute ();

            if (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                return transaction;
            }

            return null;
        }

        public Collection<MonthlyCategory> load_categories () throws SQLHeavy.Error {

            if (!category_cache.is_empty) {
                return category_cache.values as Collection<MonthlyCategory>;
            }

            var list = new TreeSet<MonthlyCategory> ();

            SQLHeavy.QueryResult results = q_load_categories.execute ();

            while (!results.finished) {
                MonthlyCategory category;
                int parent_id;

                query_result_to_category (results, out category, out parent_id);

                // TODO add to parent ???

                list.add (category);

                // add to cache too
                category_cache.@set (category.name.up (), category);

                results.next ();
            }

            return list;
        }

        public Collection<Transaction> get_current_transactions () throws SQLHeavy.Error {

            int month, year;
            Envelope.Util.Date.get_year_month (out month, out year);

            return get_transactions_for_month_and_year (month, year);
        }

        public Collection<Transaction> get_transactions_for_month_and_year (int month, int year) throws SQLHeavy.Error {

            var list = new ArrayList<Transaction> ();

            q_load_transactions_for_month_and_year.set_int ("month", month);
            q_load_transactions_for_month_and_year.set_int ("year", year);
            q_load_transactions_for_month_and_year.set_string ("date", "%4d-%02d-01".printf (year, month));

            SQLHeavy.QueryResult results = q_load_transactions_for_month_and_year.execute ();

            while (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                MonthlyCategory category;
                int parent_category_id;
                query_result_to_category (results, out category, out parent_category_id);

                transaction.category = category.@id != NULL ? category : null;

                list.add (transaction);

                results.next ();
            }

            q_load_transactions_for_month_and_year.clear ();

            return list;
        }

        public Gee.List<Transaction> get_current_transactions_for_category (Category? category) throws SQLHeavy.Error {

            var list = new ArrayList<Transaction> ();

            SQLHeavy.Query query;

            if (category != null) {
                query = q_load_current_transactions_for_category;
                query.set_int ("category_id", category.@id);
            }
            else {
                query = q_load_current_uncategorized_transactions;
            }

            SQLHeavy.QueryResult results = query.execute ();

            while (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction, category);

                list.add (transaction);

                results.next ();
            }

            query.clear ();

            return list;
        }

        public void delete_category (Category category) throws SQLHeavy.Error {
            // no need to update transactions; ON DELETE SET NULL
            q_delete_category.set_int ("category_id", category.@id);
            q_delete_category.execute ();
            q_delete_category.clear ();

            // remove from cache
            category_cache.unset (category.name.up ());
        }

        private DatabaseManager () {
            Object ();
            init_database ();
            connect_signals ();
        }

        private void query_result_to_account (SQLHeavy.QueryResult results, out Account account) throws SQLHeavy.Error {

            assert (!results.finished);

            var id = results.get_int ("id");
            var number = results.get_string ("number");
            var description = results.get_string ("description");
            var balance = results.get_double ("balance");
            int account_type = results.get_int ("type");

            account = new Account ();

            account.@id = id;
            account.number = number;
            account.description = description;
            account.balance = balance;
            account.account_type = Account.Type.from_int (account_type);
        }

        private void query_result_to_transaction (SQLHeavy.QueryResult results, out Transaction transaction, Category? category = null) throws SQLHeavy.Error {

            assert (!results.finished);

            var id = results.get_int ("id");
            var label = results.get_string ("label");
            var description = results.get_string ("description");
            var direction = results.get_int ("direction");
            var amount = results.get_double ("amount");
            var timestamp = results.get_int64 ("date");
            int category_id = results.get_int ("category_id");

            transaction = new Transaction ();

            transaction.@id = id;
            transaction.label = label;
            transaction.description = description;
            transaction.direction = Transaction.Direction.from_int (direction);
            transaction.amount = amount;
            transaction.date = new DateTime.from_unix_local (timestamp);
            transaction.account = load_account (results.get_int ("account_id"));

            if (category != null) {
                transaction.category = category;
            }
            else if (category_id != 0) {
                transaction.category = Envelope.Service.CategoryStore.get_default ().get_category_by_id (category_id);
            }
        }

        private void query_result_to_merchant (SQLHeavy.QueryResult results, out Merchant merchant) throws SQLHeavy.Error {
            assert (!results.finished);

            var label = results.get_string ("label");
            var count = results.get_int ("number");

            merchant = new Merchant (label, count);
        }

        private void query_result_to_category (SQLHeavy.QueryResult results, out MonthlyCategory category, out int parent_id) throws SQLHeavy.Error {
            assert (!results.finished);

            var id = results.get_int ("id");
            var name = results.get_string ("name");
            var description = results.get_string ("description");
            var amount_budgeted = results.get_double ("amount_budgeted");
            var year = results.get_int ("year");
            var month = results.get_int ("month");

            // parent_id is sent to caller to select parent if needed
            parent_id = results.get_int ("parent_category_id");

            category = new MonthlyCategory ();

            category.@id = id;
            category.name = name;
            category.description = description;
            category.amount_budgeted = amount_budgeted;
            category.year = year;
            category.month = month;
        }

        private void init_database () {

            var app_path = Granite.Services.Paths.user_data_folder;

            Granite.Services.Paths.ensure_directory_exists (app_path);

            var db_path = Path.build_filename (app_path.get_path (), DATABASE_FILENAME);
            var db_file = File.new_for_path (db_path);

            try {
                const SQLHeavy.FileMode flags = SQLHeavy.FileMode.READ  |
                    SQLHeavy.FileMode.WRITE |
                    SQLHeavy.FileMode.CREATE;

                debug ("database path: " + db_file.get_path ());

                database = new SQLHeavy.Database (db_file.get_path (), flags);
                database.sql_executed.connect (debug_sql);

                database.synchronous = SQLHeavy.SynchronousMode.OFF;
            }
            catch (SQLHeavy.Error err) {
                error ("Failure creating database instance (%s)", err.message);
            }

            // create tables if needed
            try {
                database.execute (TRANSACTIONS);
                database.execute (ACCOUNTS);
                database.execute (CATEGORIES);
                database.execute (MONTHLY_CATEGORIES);
                database.execute (MONTHLY_BUDGET);

                init_statements ();
            }
            catch (SQLHeavy.Error err) {
                error ("error occured during database setup (%s)", err.message);
            }

            // check if there are categories. If not, then create the default ones
            try {
                check_create_categories ();
            }
            catch (SQLHeavy.Error err) {
                error ("could not initialize default categories (%s)".printf (err.message));
            }

            database.foreign_keys = true;
        }

        private void connect_signals () {
            // invalidate merchant cache when a transaction is recorded
            transaction_created.connect ( (transaction) =>  {
                merchant_cache.clear ();
            });
        }

        /**
         * Initialize prepared statements
         *
         * TODO find a way to make this lazy
         */
        private void init_statements () throws SQLHeavy.Error {
            q_load_account                              = database.prepare (SQL_LOAD_ACCOUNT_BY_ID);
            q_load_all_accounts                         = database.prepare (SQL_LOAD_ALL_ACCOUNTS);
            q_insert_account                            = database.prepare (SQL_INSERT_ACCOUNT);
            q_rename_account                            = database.prepare (SQL_RENAME_ACCOUNT);
            q_update_account_balance                    = database.prepare (SQL_UPDATE_ACCOUNT_BALANCE);
            q_load_account_transactions                 = database.prepare (SQL_LOAD_ACCOUNT_TRANSACTIONS);
            q_delete_account_transactions               = database.prepare (SQL_DELETE_ACCOUNT_TRANSACTIONS);
            q_delete_transaction                        = database.prepare (SQL_DELETE_TRANSACTION);
            q_insert_account_transaction                = database.prepare (SQL_INSERT_TRANSACTION);
            q_get_unique_merchants                      = database.prepare (SQL_GET_UNIQUE_MERCHANTS);
            q_load_categories                           = database.prepare (SQL_LOAD_CATEGORIES);
            q_load_child_categories                     = database.prepare (SQL_LOAD_CHILD_CATEGORIES);
            q_insert_category                           = database.prepare (SQL_INSERT_CATEGORY);
            q_delete_category                           = database.prepare (SQL_DELETE_CATEOGRY);
            q_load_current_transactions                 = database.prepare (SQL_LOAD_CURRENT_TRANSACTIONS);
            q_load_current_transactions_for_category    = database.prepare (SQL_LOAD_CURRENT_TRANSACTIONS_FOR_CATEGORY);
            q_load_current_uncategorized_transactions   = database.prepare (SQL_LOAD_CURRENT_UNCATEGORIZED_TRANSACTIONS);
            q_load_uncategorized_transactions           = database.prepare (SQL_GET_UNCATEGORIZED_TRANSACTIONS);
            q_categorize_for_merchant                   = database.prepare (SQL_CATEGORIZE_ALL_FOR_MERCHANT);
            q_update_category                           = database.prepare (SQL_UPDATE_CATEGORY);
            q_delete_account                            = database.prepare (SQL_DELETE_ACCOUNT);
            q_load_transactions_for_month_and_year      = database.prepare (SQL_LOAD_TRANSACTIONS_FOR_MONTH);
            q_update_category_budgeted_amount           = database.prepare (SQL_UPDATE_CATEGORY_BUDGET);
            q_set_category_budgeted_amount              = database.prepare (SQL_SET_CATEGORY_BUDGET);
            q_check_category_budget_set                 = database.prepare (SQL_CHECK_CATEGORY_BUDGET_SET);
        }

        private void check_create_categories () throws SQLHeavy.Error {
            // check if there are categories. If not, then create the default ones
            var result = database.execute (SQL_CATEGORY_COUNT);

            assert (!result.finished);

            var category_count = result.get_int ("category_count");

            if (category_count == 0) {

                var db_transaction = start_transaction ();

                // create default categories
                var default_categories = new string[] { _("Groceries"),
                    _("Fuel"),
                    _("Public transit"),
                    _("Restaurants"),
                    _("Entertainment"),
                    _("Savings"),
                    _("Personal care"),
                    _("Alcohol & Bars"),
                    _("Emergency fund")};

                foreach (string name in default_categories) {
                    db_transaction.execute_insert (SQL_INSERT_CATEGORY_FOR_NAME, "name", typeof (string), name);
                }

                db_transaction.commit ();
            }
        }

        private void debug_sql (string sql) {
            debug ("executing query: %s", sql.strip());
        }
    }
}
