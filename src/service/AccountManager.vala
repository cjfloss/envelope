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

    public errordomain AccountError {
        ALREADY_EXISTS
    }

    private static AccountManager account_manager_instance = null;

    public class AccountManager : Object {

        construct {
            dbm = DatabaseManager.get_default ();
            account_manager_instance = this;
        }

        public static new unowned AccountManager get_default () {
            if (account_manager_instance == null) {
                account_manager_instance = new AccountManager ();
            }

            return account_manager_instance;
        }

        private DatabaseManager dbm;

        /**
         * Rename an account. The account object will be updated with the new number upon successful operation.
         *
         * @param Account account - the account to rename
         * @param string new_number - the new account number
         *
         * @return bool true if transaction suceedded, false otherwise
         */
        public void rename_account (ref Account account, string new_number) throws AccountError, ServiceError {
            try {
                dbm.rename_account (account, new_number);
                account.number = new_number;
            }
            catch (SQLHeavy.Error err) {
                if (err is SQLHeavy.Error.CONSTRAINT) {
                    throw new AccountError.ALREADY_EXISTS ("account number already exists");
                }

                throw new ServiceError.DATABASE_ERROR (err.message);
            }
        }
    }

}
