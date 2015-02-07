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

    /**
     * Data structure representing a budget state
     */
    public struct BudgetState {

        public DateTime from;
        public DateTime to;

        public double inflow;
        public double outflow;

        public double remaining { get { return inflow - outflow; }}

        public Collection<Transaction> transactions;
        public Collection<MonthlyCategory> categories;

        public double budgeted_outflow { get {

            double amount = 0d;

            foreach (MonthlyCategory category in categories) {
                amount += category.amount_budgeted;
            }

            return amount;
        }}

        public Collection<Transaction> uncategorized;

        public double uncategorized_inflow;
        public double uncategorized_outflow;

        public double budget_available { get {
            return inflow - budgeted_outflow;
        }}
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
        public signal void category_renamed (Category category, string old_name);
        public signal void category_budget_changed (MonthlyCategory category);

        private DatabaseManager dbm = DatabaseManager.get_default ();

        // cached category list
        private Collection<MonthlyCategory> categories;

        /**
         * Get all categories
         *
         * @return {Gee.ArrayList<Category>} list of categories
         */
        public Collection<MonthlyCategory> get_categories () throws ServiceError {

            if (categories != null && !categories.is_empty) {
                return categories;
            }

            try {
                categories = dbm.load_categories ();

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
        public Category create_category (string name, double budgeted_amount = 0d) throws ServiceError {

            try {
                MonthlyCategory category = new MonthlyCategory ();
                category.name = name;
                category.amount_budgeted = budgeted_amount;

                dbm.create_category (category);
                categories = null;
                category_added (category);

                return category;
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void delete_category (Category category) throws ServiceError {

            return_if_fail (category.@id != null);

            try {
                dbm.delete_category (category); // delete from database
                categories = null;              // invalidate categories cache
                category_deleted (category);    // fire the category_deleted signal
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void update_category (Category category) throws ServiceError {

            return_if_fail (category.@id != null);

            try {
                dbm.update_category (category);             // update in database
                categories = null;                          // invalidate categories cache
                compute_state_and_fire_changed_event ();    // re-compute budget state and fire state_changed
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void set_current_budgeted_amount (MonthlyCategory category) throws ServiceError {
            // get current month and year
            int month, year;
            Envelope.Util.Date.get_year_month (out month, out year);

            try {
                dbm.set_category_budgeted_amount (category, year, month);
                category_budget_changed (category);
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        public void categorize_all_for_merchant (string merchant_name, Category category) throws ServiceError {

            return_if_fail (category.@id != null);

            try {
                dbm.categorize_for_merchant (merchant_name, category);  // set category for all transactions having the same merchant
                compute_state_and_fire_changed_event ();                // re-compute budget state and fire state_changed
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Get the transactions for the current month
         */
        public Collection<Transaction> get_current_transactions () throws ServiceError {

            try {
                return dbm.get_current_transactions ();
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Get transactions recorded between the specified interval
         *
         * @return ArrayList<Transaction> list of transactions in the requested period
         */
        public Collection<Transaction> get_transactions_for_month (int year, int month) throws ServiceError {
            try {
                return dbm.get_transactions_for_month_and_year (month, year);
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }

        /**
         * Get all transactions not associated with any category
         */
        public Collection<Transaction> get_uncategorized_transactions () throws ServiceError {

            try {
                return dbm.load_uncategorized_transactions ();
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
        public Gee.List<Transaction>  compute_current_category_operations (Category? category, out double inflow, out double outflow) throws ServiceError {

            try {
                Gee.List<Transaction> transactions = dbm.get_current_transactions_for_category (category);

                debug ("transaction for category %s: %d", category != null ? category.name : "(uncategorized)", transactions.size);

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

                return transactions;
            }
            catch (SQLHeavy.Error err) {
                throw new ServiceError.DATABASE_ERROR (err.message);
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

            am.account_deleted.connect ( () => {
                compute_state_and_fire_changed_event ();
            });
        }

        /**
         * Compute the budget state for the current month
         */
        private void compute_current_state () throws ServiceError {

            // get current month and year
            int month, year;
            Envelope.Util.Date.get_year_month (out month, out year);

            // compute budget state for month and year
            BudgetState budget_state;
            compute_state_for_month (month, year, out budget_state);

            // set as global current budget state
            state = budget_state;
        }

        /**
         * Compute the budget state for the specified year and month
         */
        private void compute_state_for_month (int month, int year, out BudgetState budget_state) throws ServiceError {

            DateTime from;
            DateTime to;
            Envelope.Util.Date.get_month_boundaries (month, year, out from, out to);

            double inflow = 0d;
            double outflow = 0d;

            Collection<Transaction> transactions = get_transactions_for_month (year, month);
            Collection<Transaction> uncategorized = new ArrayList<Transaction> ();

            foreach (Transaction t in transactions) {

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

                if (t.category == null) {
                    uncategorized.add (t);
                }
            }

            budget_state = BudgetState ();
            budget_state.from = from;
            budget_state.to = to;
            budget_state.inflow = inflow;
            budget_state.outflow = outflow;
            budget_state.uncategorized = uncategorized;
            budget_state.transactions = transactions;
            budget_state.categories = get_categories ();
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

        /**
         * Check if a month transition is needed
         */
        private bool should_handle_month_transition () throws ServiceError {

            // get the max() value of month, year from the monthly_budgets table

            // if the max month, year == this month - 1, then we need to do a month transition

            return false;
        }

        /**
         * Persist budget state at the end of the month, and
         * take remaining budget for each caegory, add it to the
         * budgeted amount for that category and set the new amount
         * as next month's budgeted amount for that category
         */
        private void manage_month_transition () throws ServiceError {

            // first, get transactions from the previous month

            // for each of them, compute in/out flow for its category (if present)

            // persist monthly category's in/out flow for previous month

            // persist overall budget state for previous month

            // compute remaining amounts for each category

            // persist monthly categories for current month with budgeted amount from last month's + remaining

            // compute current budget state
        }
    }
}
