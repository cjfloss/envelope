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


namespace Envelope {

    /**
     * A category subclass which has a budgeted amount for a specific month in history
     */
    public class MonthlyCategory : Category {

        // year and month for this category's budget
        public uint month { get; set; }
        public uint year { get; set; }

        // budgeted amount for the month
        public double amount_budgeted { get; set; default = 0d; }

        /**
         * Creates a new MonthlyCategory for the current month
         */
        public MonthlyCategory () {

            Object ();

            uint o_month, o_year;
            Envelope.Util.Date.get_year_month (out o_month, out o_year);

            month = o_month;
            year = o_year;
        }

        /**
         * Creates a new MonthlyCategory for the specified year and month
         */
        public MonthlyCategory.for_month (uint year, uint month) {

            Object ();

            this.month = month;
            this.year = year;
        }

    }
}
