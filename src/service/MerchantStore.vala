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

using Envelope.DB;
using Gee;

namespace Envelope.Service {

    public class MerchantStore : Gtk.ListStore {

        private static MerchantStore merchant_store_instance = null;

        public static new unowned MerchantStore get_default () {
            if (merchant_store_instance == null) {
                merchant_store_instance = new MerchantStore ();
            }

            return merchant_store_instance;
        }

        public static const int COLUMN = 0;

        private MerchantStore () {
            Object ();
            build_store ();
            reload ();
        }

        public void reload () {
            clear ();
            try {
                load_merchants ();
            }
            catch (SQLHeavy.Error err) {
                warning ("could not load merchants; transaction search autocompletion won't work (%s)".printf (err.message));
            }
        }

        private void build_store () {
            set_column_types ({typeof (string), typeof (int)});
        }

        private void load_merchants () throws SQLHeavy.Error {
            Collection<Merchant> merchants = DatabaseManager.get_default ().get_merchants ();

            if (!merchants.is_empty) {

                foreach (Merchant m in merchants) {

                    Gtk.TreeIter iter;
                    append (out iter);

                    @set (iter, COLUMN, m.label, 1, m.occurences, -1);
                }
            }
        }
    }
}
