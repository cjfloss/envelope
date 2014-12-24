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

using Envelope.Service;
using Gee;

namespace Envelope.Service {

    private static CategoryStore category_store_instance = null;

    public class CategoryStore : Gtk.ListStore {



        public static new unowned CategoryStore get_default () {
            if (category_store_instance == null) {
                category_store_instance = new CategoryStore ();
            }

            return category_store_instance;
        }

        public enum Column {
            LABEL,
            CATEGORY
        }

        public void reload () {
            try {
                ArrayList<Category> categories = BudgetManager.get_default ().get_categories ();

                foreach (Category category in categories) {
                    Gtk.TreeIter iter;

                    append (out iter);
                    @set (iter, Column.LABEL, category.name, Column.CATEGORY, category, -1);
                }
            }
            catch (ServiceError err) {
                warning ("could not load categories; autocompletion won't work in the transaction view (%s)", err.message);
            }
        }

        public Category get_category_by_name (string name) {
            Category? category = null;

            @foreach ( (model, path, iter) => {

                Category fe_category;
                model.@get (iter, Column.CATEGORY, out fe_category, -1);

                if (fe_category != null && fe_category.name.up () == name.strip ().up ()) {
                    debug ("search (%s) --> %s", name, fe_category.name);
                    category = fe_category;
                }

                return category != null;
            });

            return category;
        }

        public Category get_category_by_id (int id) {
            Category? category = null;

            @foreach ( (model, path, iter) => {

                Category fe_category;

                model.@get (iter, Column.CATEGORY, out fe_category, -1);

                if (fe_category.@id == id) {
                    debug ("search (%d) --> %s", id, fe_category.name);
                    category = fe_category;
                }

                return category != null;
            });

            return category;
        }

        private CategoryStore () {
            Object ();
            build_store ();
            connect_signals ();
            reload ();
        }

        private void build_store () {
            set_column_types ({typeof (string), typeof (Category)});
        }

        private void connect_signals () {

            var budget_manager = BudgetManager.get_default ();

            budget_manager.category_added.connect ( (category) => {
                debug ("category added; reloading store");
                reload ();
            });

            budget_manager.category_deleted.connect ( (category) => {
                debug ("category deleted; reloading store");
                reload ();
            });
        }
    }
}
