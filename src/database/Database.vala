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

namespace Envelope.DB {

    static const string ACCOUNTS = """
        CREATE TABLE IF NOT EXISTS accounts (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT,
            `number` TEXT NOT NULL,
            `description` TEXT,
            `balance` DOUBLE,
            `type` INT)
        """;

    static const string TRANSACTIONS = """
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
        FOREIGN KEY (`parent_transaction_id`) REFERENCES `transactions`(`id`),
        FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`),
        FOREIGN KEY (`account_id`) REFERENCES `accounts`(`id`))
        """;

    static const string CATEGORIES = """
        CREATE TABLE IF NOT EXISTS categories (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT,
            `name` TEXT NOT NULL,
            `description` TEXT,
            `amount_budgeted` DOUBLE,
            `parent_category_id` INT,
        FOREIGN KEY (`parent_category_id`) REFERENCES `category`(`id`))
        """;

    class DatabaseManager : Object {

        public signal void account_created (Account account);
        public signal void account_deleted (Account account);
        public signal void accout_updated (Account account);

        public signal void category_created (Category category);

        private static DatabaseManager database_manager_instance = null;

        // database handler
        private SQLHeavy.Database database;

        // prepared statements
        private SQLHeavy.Query q_load_account;
        private SQLHeavy.Query q_load_all_accounts;
        private SQLHeavy.Query q_insert_account;
        private SQLHeavy.Query q_rename_account;
        private SQLHeavy.Query q_update_account_balance;

        private SQLHeavy.Query q_load_account_transactions;
        private SQLHeavy.Query q_delete_account_transactions;
        private SQLHeavy.Query q_insert_account_transaction;
        private SQLHeavy.Query q_delete_transaction;

        private SQLHeavy.Query q_load_current_transactions;
        private SQLHeavy.Query q_load_current_transactions_for_category;

        private SQLHeavy.Query q_get_unique_merchants;

        private SQLHeavy.Query q_load_categories;
        private SQLHeavy.Query q_load_child_categories;
        private SQLHeavy.Query q_insert_category;
        private SQLHeavy.Query q_delete_category;

        public static new DatabaseManager get_default () {
            if (database_manager_instance == null) {
                database_manager_instance = new DatabaseManager ();
            }

            return database_manager_instance;
        }

        public SQLHeavy.Transaction start_transaction () throws SQLHeavy.Error {
            return database.begin_transaction ();
        }

        public Gee.ArrayList<Merchant> get_merchants () {
            var merchants = new Gee.ArrayList<Merchant> ();

            try {
                SQLHeavy.QueryResult results = q_get_unique_merchants.execute ();

                while (!results.finished) {
                    Merchant merchant;
                    query_result_to_merchant (results, out merchant);

                    merchants.add (merchant);

                    results.next ();
                }
            }
            catch (SQLHeavy.Error err) {
                error ("error occured while loading merchants (%s)".printf (err.message));
            }

            debug ("loaded %d unique merchants".printf (merchants.size));

            foreach (Merchant m in merchants) {
                debug ("merchant: %s (%d)".printf (m.label, m.occurences));
            }

            return merchants;
        }

        public Account? load_account (int account_id) {

            try {
                q_load_account.clear ();
                q_load_account.set_int ("accountid", account_id);

                SQLHeavy.QueryResult results = q_load_account.execute ();

                if (!results.finished) {
                    Account account;

                    query_result_to_account (results, out account);

                    return account;
                }

                error ("query returned no results for account %d".printf (account_id));
            }
            catch (SQLHeavy.Error err) {
                error ("could not load account %d (%s)".printf (account_id, err.message));
            }
        }

        public Gee.ArrayList<Account> load_all_accounts () throws SQLHeavy.Error {
            var list = new Gee.ArrayList<Account> ();

            q_load_all_accounts.clear ();

            SQLHeavy.QueryResult results = q_load_all_accounts.execute ();

            while (!results.finished) {
                Account account;
                query_result_to_account (results, out account);

                //account.transactions = get_mocked_transactions ();

                list.add (account);

                results.next ();
            }

            debug ("loaded %d account(s)".printf (list.size));

            return list;
        }

        public void create_category (Category category) throws SQLHeavy.Error {

            debug ("inserting category '%s' in database".printf (category.name));

            var id = q_insert_category.execute_insert (
                "name", typeof (string), category.name,
                "description", typeof (string), category.description,
                "amount_budgeted", typeof (double), category.amount_budgeted,
                "parent_category_id", typeof (int), null
            );

            debug ("category created with id %d".printf ((int) id));

            category.@id = (int) id;

            category_created (category);
        }

        public void create_account (Account account) throws SQLHeavy.Error {

            debug ("inserting the following account: number: %s, description: %s, balance: %s, type: %s".printf
                (account.number, account.description, account.balance.to_string (), account.account_type.to_string ()));

            var id = q_insert_account.execute_insert (
                "number", typeof (string), account.number,
                "description", typeof (string), account.description,
                "balance", typeof (double), account.balance,
                "type", typeof (int), (int) account.account_type
                );

            debug ("account created with id %d".printf ((int) id));

            account.@id = (int) id;

            // notify account created
            account_created (account);
        }

        public void rename_account (Account account, string new_name) throws SQLHeavy.Error {

            q_rename_account.set_int ("account_id", account.@id);
            q_rename_account.set_string ("number", new_name);

            q_rename_account.execute ();

            q_rename_account.clear ();
        }

        public void update_account_balance (Account account, ref SQLHeavy.Transaction transaction)  throws SQLHeavy.Error {
            transaction.prepare ("UPDATE `accounts` SET `balance` = :balance WHERE `id` = :account_id")
                .execute ("balance", typeof (double), account.balance, "account_id", typeof (int), account.@id);
        }

        public Gee.ArrayList<Transaction> load_account_transactions (Account account) {

            debug ("loading transactions for account %d".printf (account.@id));

            Gee.ArrayList<Transaction> list = new Gee.ArrayList<Transaction> ();

            try {
                q_load_account_transactions.clear ();
                q_load_account_transactions.set_int ("account_id", account.@id);

                SQLHeavy.QueryResult results = q_load_account_transactions.execute ();

                while (!results.finished) {
                    Transaction transaction;
                    query_result_to_transaction (results, out transaction);

                    transaction.account = account;
                    list.add (transaction);

                    results.next ();
                }
            }
            catch (SQLHeavy.Error err) {
                error ("could not load transactions for account %d (%s)".printf (account.@id, err.message));
            }

            return list;
        }

        public void insert_transaction (Transaction transaction, ref SQLHeavy.Transaction db_transaction, SQLHeavy.Query? statement = null) throws SQLHeavy.Error {

            debug ("inserting new transaction in account %d".printf (transaction.account.@id));

            var q = statement != null ? statement : db_transaction.prepare("""
                INSERT INTO `transactions`
                (`label`, `description`, `amount`, `direction`, `account_id`, `parent_transaction_id`, `date`, `category_id`)
                VALUES
                (:label, :description, :amount, :direction, :account_id, :parent_transaction_id, :date, :category_id)
                """);

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
        }

        /**
         * Insert multiple transactions
         */
        public void insert_transactions (Gee.ArrayList<Transaction> transactions, ref SQLHeavy.Transaction transaction) throws SQLHeavy.Error {

            var stmt = transaction.prepare ("""
            INSERT INTO `transactions`
            (`label`, `description`, `amount`, `direction`, `account_id`, `parent_transaction_id`, `date`, 'category_id')
            VALUES
            (:label, :description, :amount, :direction, :account_id, :parent_transaction_id, :date, :category_id)
            """);

            foreach (Transaction t in transactions) {
                insert_transaction (t, ref transaction, stmt);
            }
        }

        public void delete_transaction (int transaction_id, ref SQLHeavy.Transaction db_transaction) throws SQLHeavy.Error {

            var stmt = db_transaction.prepare ("DELETE FROM `transactions` WHERE `id` = :id");
            stmt.set_int ("id", transaction_id);

            stmt.execute ();
        }

        public Gee.ArrayList<Category> load_categories () throws SQLHeavy.Error {

            debug ("loading categories");

            Gee.ArrayList<Category> list = new Gee.ArrayList<Category> ();

            SQLHeavy.QueryResult results = q_load_categories.execute ();

            while (!results.finished) {
                Category category;
                int parent_id;

                query_result_to_category (results, out category, out parent_id);

                // TODO add to parent ???

                list.add (category);

                results.next ();
            }

            return list;
        }

        public Gee.ArrayList<Transaction> get_current_transactions () throws SQLHeavy.Error {

            Gee.ArrayList<Transaction> list = new Gee.ArrayList<Transaction> ();

            SQLHeavy.QueryResult results = q_load_current_transactions.execute ();

            while (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction);

                list.add (transaction);

                results.next ();
            }

            return list;
        }

        public Gee.ArrayList<Transaction> get_current_transactions_for_category (Category category) throws SQLHeavy.Error {

            Gee.ArrayList<Transaction> list = new Gee.ArrayList<Transaction> ();

            q_load_current_transactions_for_category.clear ();
            q_load_current_transactions_for_category.set_int ("category_id", category.@id);

            SQLHeavy.QueryResult results = q_load_current_transactions_for_category.execute ();

            while (!results.finished) {
                Transaction transaction;
                query_result_to_transaction (results, out transaction, category);

                list.add (transaction);

                results.next ();
            }

            return list;
        }

        private DatabaseManager () {
            init_database ();
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
            var account_id = results.get_int ("account_id");
            var parent_id = results.get_int ("parent_transaction_id");
            var timestamp = results.get_int64 ("date");
            int? category_id = results.get_int ("category_id");

            transaction = new Transaction ();

            transaction.@id = id;
            transaction.label = label;
            transaction.description = description;
            transaction.direction = Transaction.Direction.from_int (direction);
            transaction.amount = amount;
            transaction.date = new DateTime.from_unix_local (timestamp);

            if (category != null) {
                transaction.category = category;
            }
            else if (category_id != null) {
                var cat = Envelope.Service.CategoryStore.get_default ().get_category_by_id (category_id);

                if (cat != null) {
                    transaction.category = cat;
                    debug ("transaction category: %s", transaction.category.name);
                }
            }
        }

        private void query_result_to_merchant (SQLHeavy.QueryResult results, out Merchant merchant) throws SQLHeavy.Error {
            assert (!results.finished);

            var label = results.get_string ("label");
            var count = results.get_int ("number");

            merchant = new Merchant (label, count);
        }

        private void query_result_to_category (SQLHeavy.QueryResult results, out Category category, out int parent_id) throws SQLHeavy.Error {
            assert (!results.finished);

            var id = results.get_int ("id");
            var name = results.get_string ("name");
            var description = results.get_string ("description");
            var amount_budgeted = results.get_double ("amount_budgeted");

            // parent_id is sent to caller to select parent if needed
            parent_id = results.get_int ("parent_category_id");

            category = new Category ();

            category.@id = id;
            category.name = name;
            category.description = description;
            category.amount_budgeted = amount_budgeted;
        }

        private void init_database () {

            var app_path = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                Environment.get_user_data_dir (), Build.PROGRAM_NAME));

            try {
                app_path.make_directory_with_parents (null);
            }
            catch (GLib.Error err) {
                if (!(err is IOError.EXISTS)) {
                    // TODO error could not create database path
                }
            }

            string db_path = Path.build_filename (app_path.get_path (), "database.db");
            var db_file = File.new_for_path (db_path);

            try {
                const SQLHeavy.FileMode flags = SQLHeavy.FileMode.READ  |
                    SQLHeavy.FileMode.WRITE |
                    SQLHeavy.FileMode.CREATE;

                debug ("database path: " + db_file.get_path ());

                database = new SQLHeavy.Database (db_file.get_path (), flags);
                database.sql_executed.connect (debug_sql);
            }
            catch (SQLHeavy.Error err) {
                error ("Failure creating database instance (%s)", err.message);
            }

            try {
                load_table (TRANSACTIONS);
                load_table (ACCOUNTS);
                load_table (CATEGORIES);

                init_statements ();
            }
            catch (SQLHeavy.Error err) {
                error ("error occured during database setup (%s)".printf (err.message));
            }

            // TODO check if there are categories. If not, then create the default ones
            try {
                var result = database.execute ("SELECT COUNT(*) AS category_count from categories");

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
                                                            _("Alcohol &amp; Bars"),
                                                            _("Emergency fund")};

                    foreach (string name in default_categories) {
                        db_transaction.execute_insert ("INSERT INTO `categories` (`name`) VALUES (:name);", "name", typeof (string), name);
                    }

                    db_transaction.commit ();
                }
            }
            catch (SQLHeavy.Error err) {
                error ("could not initialize default categories (%s)".printf (err.message));
            }

            // TODO check if this is necessary
            database.synchronous = SQLHeavy.SynchronousMode.OFF;
        }

        private void init_statements () throws SQLHeavy.Error {

            debug ("creating prepared statements");

            q_load_account = database.prepare ("""
            SELECT * FROM `accounts` WHERE `id` = :accountid;
            """);

            q_load_all_accounts = database.prepare ("""
            SELECT * FROM `accounts` ORDER BY `number`;
            """);

            q_insert_account = database.prepare ("""
            INSERT INTO `accounts`
            (`number`, `description`, `balance`, `type`)
            VALUES
            (:number, :description, :balance, :type);
            """);

            q_rename_account = database.prepare ("""
            UPDATE `accounts` SET `number` = :number WHERE `id` = :account_id
            """);

            q_update_account_balance = database.prepare ("""
            UPDATE `accounts` SET `balance` = :balance WHERE `id` = :account_id
            """);

            q_load_account_transactions = database.prepare("""
            SELECT * FROM `transactions` WHERE `account_id` = :account_id ORDER BY `date` DESC
            """);

            q_delete_account_transactions = database.prepare("""
            DELETE FROM `transactions` WHERE `account_id` = :account_id
            """);

            q_delete_transaction = database.prepare ("""
            DELETE FROM `transactions` WHERE `id` = :id
            """);

            q_insert_account_transaction = database.prepare("""
            INSERT INTO `transactions`
            (`label`, `description`, `amount`, `direction`, `account_id`, `parent_transaction_id`, `date`)
            VALUES
            (:label, :description, :amount, :direction, :account_id, :parent_transaction_id, :date)
            """);

            q_get_unique_merchants = database.prepare("""
            SELECT `label`, COUNT(`label`) as `number` FROM `transactions` GROUP BY `label` ORDER BY `number` DESC, `label` ASC
            """);

            q_load_categories = database.prepare("""
            SELECT * FROM `categories` ORDER BY `name` ASC
            """);

            q_load_child_categories = database.prepare ("""
            SELECT * FROM `categories` WHERE `parent_category_id` = :parent_category_id ORDER BY `name` ASC
            """);

            q_insert_category = database.prepare ("""
            INSERT INTO `categories`
            (`name`, `description`, `amount_budgeted`, `parent_category_id`)
            VALUES
            (:name, :description, :amount_budgeted, :parent_category_id)
            """);

            q_delete_category = database.prepare ("""
            DELETE FROM `categories` WHERE `id` = :category_id
            """);

            q_load_current_transactions = database.prepare("""
            SELECT * FROM transactions WHERE date(date, 'unixepoch') BETWEEN date('now', 'start of month') AND date('now', 'start of month', '+1 month', '-1 days')
            """);

            q_load_current_transactions_for_category = database.prepare("""
            SELECT * FROM transactions WHERE date(date, 'unixepoch') BETWEEN date('now', 'start of month') and date('now', 'start of month', '+1 month', '-1 days') AND category_id = :category_id
            """);
        }

        private void load_table (string table) {
            try {
                database.execute (table);
            }
            catch (SQLHeavy.Error err) {
                // TODO could not create table
                debug ("could not load table (%s)".printf (err.message));
            }
        }

        private void debug_sql (string sql) {
            debug (sql.strip());
        }
    }
}
