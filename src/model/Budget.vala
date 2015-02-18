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
using Envelope.Service;

namespace Envelope {

    public class Budget : Object {

        private static Budget budget_instance = null;

        public static new Budget get_default () {
            if (budget_instance == null) {
                budget_instance = new Budget ();
            }

            return budget_instance;
        }

        public ArrayList<Category> categories { get; set; }

        public BudgetState current_state { get; set; }

        private Budget () {
            Object ();
            connect_signals ();
        }

        private void connect_signals () {
            /*
            connect signals in order to update current_state whenever a transaction/account
            is added/updated/removed
            */
        }
    }
}
