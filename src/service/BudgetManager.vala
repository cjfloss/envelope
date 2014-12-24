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

    public struct BudgetState {

        DateTime from;
        DateTime to;

        double inflow;
        double outflow;

        ArrayList<Transaction> transactions;
        ArrayList<Category> categories;
    }

    private static BudgetManager budget_manager_instance = null;

    public class BudgetManager : Object {

        public static BudgetManager get_default () {

            if (budget_manager_instance == null) {

                budget_manager_instance = new BudgetManager ();

                try {
                    budget_manager_instance.compute_current_state ();
                }
                catch (ServiceError err) {
                    error ("could not initialize budget state (%s)", err.message);
                }
            }

            return budget_manager_instance;
        }

        public BudgetState? state { get; private set; }

        public signal void budget_changed (BudgetState state);

        public signal void category_added (Category category);
        public signal void category_deleted (Category category);

        private DatabaseManager dbm = DatabaseManager.get_default ();

        /**
         * Get all categories
         *
         * @return {Gee.ArrayList<Category>} list of categories
         */
        public ArrayList<Category> get_categories () throws ServiceError {

            try {
                var categories = dbm.load_categories ();

                if (!categories.is_empty) {
                    categories.sort ();
                }

                debug ("loaded %d categorie(s)".printf (categories.size));

                return categories;
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Create a new category having the specified name
         *
         * @param {string} name - the name of the category
         * @return {Category} the new category
         */
        public Category create_category (string name) throws ServiceError {

            try {
                Category category = new Category ();
                category.name = name;

                dbm.create_category (category);

                category_added (category);

                return category;
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Get the transactions for the current month
         */
        public ArrayList<Transaction> get_current_transactions () throws ServiceError {

            try {
                return dbm.get_current_transactions ();
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Get the total inflow and outflow in the current month for the specified category
         *
         * @param {Category} category
         * @param {double} inflow
         * @param {double} outflow
         */
        public void compute_current_category_operations (Category category, out double inflow, out double outflow) {
            try {
                ArrayList<Transaction> transactions = dbm.get_current_transactions_for_category (category);

                debug ("transaction for category %s: %d", category.name, transactions.size);

                inflow = 0d;
                outflow = 0d;

                foreach (Transaction transaction in transactions) {
                    switch (transaction.direction) {
                        case Transaction.Direction.INCOMING:
                            inflow += transaction.amount;
                            break;
                        case Transaction.Direction.OUTGOING:
                            outflow += transaction.amount;
                            break;
                        default:
                            assert_not_reached ();
                    }
                }
            }
            catch (SQLHeavy.Error err) {

            }
        }

        private BudgetManager () {
            connect_signals ();
        }

        private void connect_signals () {
            var am = AccountManager.get_default ();

            // listen to transaction operations
            am.transaction_recorded.connect ( () =>  {
                compute_state_and_fire_changed_event ();
            });

            am.transactions_imported.connect ( () =>  {
                compute_state_and_fire_changed_event ();
            });

            am.transaction_updated.connect ( () =>  {
                compute_state_and_fire_changed_event ();
            });

            am.transaction_deleted.connect ( () =>  {
                compute_state_and_fire_changed_event ();
            });
        }

        /**
         * Compute the budget state for the current month
         */
        private void compute_current_state () throws ServiceError {

            DateTime from;
            DateTime to;
            double inflow = 0d;
            double outflow = 0d;

            compute_dates (out from, out to);

            foreach (Transaction t in get_current_transactions ()) {

                switch (t.direction) {
                    case Transaction.Direction.INCOMING:
                        inflow += t.amount;
                        break;

                    case Transaction.Direction.OUTGOING:
                        outflow += t.amount;
                        break;

                    default:
                        assert_not_reached ();
                }
            }

            var budget_state = state == null ? BudgetState () : state;

            budget_state.from = from;
            budget_state.to = to;
            budget_state.inflow = inflow;
            budget_state.outflow = outflow;

            state = budget_state;
        }

        /**
         * Determine start and end dates for current month
         */
        private void compute_dates (out DateTime from, out DateTime to) {

            var now = new DateTime.now_local ();

            from = new DateTime.local (now.get_year (), now.get_month (), 1, 0, 0, 0);
            to = new DateTime.local (now.get_year (), now.get_month (), 1, 0, 0, 0);

            // compute last day
            to = to.add_months (1).add_days (-1);
        }

        /**
         * Compute the budget state and fire the budget_changed signal with it
         */
        private void compute_state_and_fire_changed_event () {

            debug ("compute_state_and_fire_changed_event");

            try {
                compute_current_state ();
                budget_changed (state);
            }
            catch (ServiceError err) {
                error ("could not compute budget state (%s)", err.message);
            }
        }
    }
}
