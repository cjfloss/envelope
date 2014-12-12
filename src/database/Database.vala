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

using Granite.Services;

namespace Envelope {
    class DatabaseManager : Object {

        private static DatabaseManager? dbm = null;

        private static const string APP_NAME = "envelope"; // TODO get from build system

        // database handler
        private SQLHeavy.Database database;

        // prepared statements
        private SQLHeavy.Query q_load_account;
        private SQLHeavy.Query q_load_all_accounts;
        private SQLHeavy.Query q_insert_account;

        public static DatabaseManager get_default () {
            if (dbm == null) {
                dbm = new DatabaseManager ();
            }

            return dbm;
        }

        public Account? load_account (int account_id) {

            try {
                q_load_account.clear ();
                q_load_account.set_int ("accountid", account_id);

                SQLHeavy.QueryResult results = q_load_account.execute ();

                if (results.next ()) {
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

        public Gee.ArrayList<Account> load_all_accounts () {
            var list = new Gee.ArrayList<Account> ();

            try {
                q_load_all_accounts.clear ();

                SQLHeavy.QueryResult results = q_load_all_accounts.execute ();

                while (results.next ()) {
                    Account account;

                    query_result_to_account (results, out account);

                    account.transactions = get_mocked_transactions ();

                    list.add (account);
                }
            }
            catch (SQLHeavy.Error err) {
                error ("could not load all accounts (%s)".printf (err.message));
            }

            debug ("loaded %d account(s)".printf (list.size));

            return list;
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
        }

        public Gee.ArrayList<Budget>? load_budgets () {
            return null;
        }

        public Budget? load_budget (int budget_id) {
            return null;
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

        private void init_database () {

            var app_path = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                Environment.get_user_data_dir (), APP_NAME));

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
            }
            catch (SQLHeavy.Error err) {
                error ("Failure creating database instance (%s)", err.message);
            }

            try {
                load_table (Envelope.Tables.BUDGETS);
                load_table (Envelope.Tables.TRANSACTIONS);
                load_table (Envelope.Tables.ACCOUNTS);

                init_statements ();
            }
            catch (SQLHeavy.Error err) {
                error ("error occured during database setup (%s)".printf (err.message));
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
        }

        private void load_table (string table) {

            debug ("load table: %s".printf (table));

            try {
                database.execute (table);
            }
            catch (SQLHeavy.Error err) {
                // TODO could not create table
                debug ("could not load table (%s)".printf (err.message));
            }
        }

        private Gee.ArrayList<Transaction> get_mocked_transactions () {
            Gee.ArrayList<Transaction> list = new Gee.ArrayList<Transaction> ();

            for (int i = 0; i < 10; i++) {
                var trans = new Transaction ();

                trans.label = "transaction %d".printf (i);
                trans.amount = 100 + i;

                trans.date = new DateTime.now_local ().add_days (i);

                trans.direction = i % 2 == 0 ? Transaction.Direction.INCOMING : Transaction.Direction.OUTGOING;

                trans.description = "description for %d".printf (i);

                trans.@id = i;

                list.add (trans);

                if (i == 4) {
                    var child = new Transaction ();
                    child.label = "child transaction";
                    child.amount = 259.34;
                    child.direction = Transaction.Direction.INCOMING;
                    child.date = new DateTime.now_local ();
                    child.description = "this is a child";

                    child.parent = trans;

                    child.@id = i * 2000;

                    list.add (child);
                }


            }

            // Transaction is comparable; sort
            list.sort();

            return list;
        }

    }
}
