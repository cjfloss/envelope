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

        /**
         * Reload the store
         */
        public void reload () {
            try {
                Collection<MonthlyCategory> categories = BudgetManager.get_default ().get_categories ();

                foreach (MonthlyCategory category in categories) {

                    Gtk.TreeIter iter;
                    append (out iter);

                    @set (iter, Column.LABEL, category.name, Column.CATEGORY, category, -1);
                }
            }
            catch (ServiceError err) {
                warning ("could not load categories; autocompletion won't work (%s)", err.message);
            }
        }

        /**
         * Get a category instance from its name
         *
         * @param name the name of the category to lookup
         * @return the category instance, or null if not found
         */
        public Category? get_category_by_name (string name) {

            Category? category = null;

            @foreach ( (model, path, iter) => {

                Category fe_category;
                model.@get (iter, Column.CATEGORY, out fe_category, -1);

                if (fe_category != null && fe_category.name.up () == name.strip ().up ()) {
                    category = fe_category;
                }

                return category != null;
            });

            return category;
        }

        /**
        * Get a category instance from its id
        *
        * @param id the id of the category to lookup
        * @return the category instance, or null if not found
        */
        public Category get_category_by_id (int id) {
            Category? category = null;

            @foreach ( (model, path, iter) => {

                Category fe_category;

                model.@get (iter, Column.CATEGORY, out fe_category, -1);

                if (fe_category.@id == id) {
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
        }

        private void build_store () {
            set_column_types ({typeof (string), typeof (MonthlyCategory)});
            reload ();
        }

        private void connect_signals () {

            var budget_manager = BudgetManager.get_default ();

            budget_manager.category_added.connect ( (category) => {
                debug ("category added; reloading");
                reload ();
            });

            budget_manager.category_deleted.connect ( (category) => {
                debug ("category deleted; reloading");
                reload ();
            });

            budget_manager.category_renamed.connect ( (category) => {
                debug ("category renamed; reloading");
                reload ();
            });
        }
    }
}
