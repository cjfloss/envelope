/*
 * Copyright (C) 2009,2011 Jens Georg <mail@jensge.org>.
 *
 * Author: Jens Georg <mail@jensge.org>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Adapted to Envelope
 */

using Sqlite;

namespace Envelope.Database {

    /**
     * Special GValue to pass to exec or exec_cursor to bind a column to
     * NULL
     */
    public static GLib.Value @null () {
        GLib.Value v = GLib.Value (typeof (void *));
        v.set_pointer (null);

        return v;
    }

    /**
     * This class is a thin wrapper around SQLite's database object.
     *
     * It adds statement preparation based on GValue and a cancellable exec
     * function.
     */
    public class Database : Object, Initable {

        public string name { private get; construct set; default = "envelope.db"; }

        private Sqlite.Database db;

        /**
         * Connect to a SQLite database file
         *
         * @param name Name of the database which is used to create the file-name
         */
        public Database (string name)
                         throws DatabaseError, Error {
            Object (name : name);
            init ();
        }

        /**
         * Initialize database. Implemented for Initiable interface.
         *
         * @param cancellable a cancellable (unused)
         * @return true on success, false on error
         * @throws DatabaseError if anything goes wrong
         */
        public bool init (Cancellable? cancellable = null) throws Error {
            var app_path = Granite.Services.Paths.user_data_folder;

            Granite.Services.Paths.ensure_directory_exists (app_path);

            var db_path = Path.build_filename (app_path.get_path (), this.name);
            var db_file = File.new_for_path (db_path);

            try {
                const int flags = Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE;

                debug ("database path: " + db_file.get_path ());

                Sqlite.Database.open_v2 (db_file.get_path (), out db, flags);
                if (db.errcode () != Sqlite.OK) {
                    var msg = _("Error while opening SQLite database %s: %s");
                    throw new DatabaseError.OPEN (msg, db_file.get_path (), this.db.errmsg ());
                }

                //TODO debug executed sql queries
                //db.sql_executed.connect (debug_sql);
            } catch (DatabaseError e) {
                error ("SQLITE_ERROR: %d: %s\n", e.code, e.message);
            }

            return true;
        }

        /**
         * SQL query function.
         *
         * Use for all queries that return a result set.
         *
         * @param sql The SQL query to run.
         * @param arguments Values to bind in the SQL query or null.
         * @throws DatabaseError if the underlying SQLite operation fails.
         */
        public Cursor exec_cursor (string        sql,
                                   GLib.Value[]? arguments = null)
                                   throws DatabaseError {
            return new Cursor (this.db, sql, arguments);
        }

        /**
         * Simple SQL query execution function.
         *
         * Use for all queries that don't return anything.
         *
         * @param sql The SQL query to run.
         * @param arguments Values to bind in the SQL query or null.
         * @throws DatabaseError if the underlying SQLite operation fails.
         */
        public void exec (string        sql,
                          GLib.Value[]? arguments = null)
                          throws DatabaseError {
            if (arguments == null) {
                debug (sql);
                this.db.exec (sql);
                if (this.db.errcode () != Sqlite.OK) {
                    var msg = "Failed to run query %s: %s";
                    throw new DatabaseError.SQLITE_ERROR (msg, sql, this.db.errmsg ());
                }

                return;
            }
            var cursor = this.exec_cursor (sql, arguments);
            while (cursor.has_next ()) {
                cursor.next ();
            }
        }

        /**
         * Return the Last inserted row id
         *
         * Use to get database row id after an insertion
         */
        public int64 last_insert_rowid () {
            return this.db.last_insert_rowid ();
        }

        /**
         * Execute a SQL query that returns a single number.
         *
         * @param sql The SQL query to run.
         * @param args Values to bind in the SQL query or null.
         * @return The contents of the first row's column as an int.
         * @throws DatabaseError if the underlying SQLite operation fails.
         */
        public int query_value (string        sql,
                                 GLib.Value[]? args = null)
                                 throws DatabaseError {
            var cursor = this.exec_cursor (sql, args);
            var statement = cursor.next ();
            return statement->column_int (0);
        }

        /**
         * Analyze triggers of database
         */
        public void analyze () {
            this.db.exec ("ANALYZE;");
        }

        /**
         * Start a transaction
         */
        public void begin () throws DatabaseError {
            this.exec ("BEGIN;");
        }

        /**
         * Commit a transaction
         */
        public void commit () throws DatabaseError {
            this.exec ("COMMIT;");
        }

        /**
         * Rollback a transaction
         */
        public void rollback () {
            try {
                this.exec ("ROLLBACK;");
            } catch (DatabaseError error) {
                critical (_("Failed to roll back transaction: %s"),
                          error.message);
            }
        }

        /**
         * Check for an empty SQLite database.
         * @return true if the file is an empty SQLite database, false otherwise
         * @throws DatabaseError if the SQLite meta table does not exist which
         * usually indicates that the file is not a databsae
         */
        public bool is_empty () throws DatabaseError {
            return this.query_value ("SELECT count(type) FROM " +
                                     "sqlite_master WHERE rowid = 1;") == 0;
        }
    }
}