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

using Envelope.Database;
using Gee;

namespace Envelope.Service {
    public class PayeeStore : Gtk.ListStore {
        private static PayeeStore payee_store_instance = null;

        public static new unowned PayeeStore get_default () {
            if (payee_store_instance == null) {
                payee_store_instance = new PayeeStore ();
            }

            return payee_store_instance;
        }

        public const int COLUMN = 0;

        private PayeeStore () {
            Object ();
            set_column_types ({typeof (string), typeof (int)});
            reload ();
        }

        public void reload () {
            clear ();
            try {
                load_payees ();
            } catch (DatabaseError err) {
                warning ("could not load payees; transaction search autocompletion won't work (%s)".printf (err.message));
            }
        }

        private void load_payees () throws DatabaseError {
            Collection<Payee> payees = DatabaseManager.get_default ().get_payees ();

            if (!payees.is_empty) {
                foreach (Payee m in payees) {
                    Gtk.TreeIter iter;
                    append (out iter);

                    @set (iter, COLUMN, m.label, 1, m.occurences, -1);
                }
            }
        }
    }
}
