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

namespace Envelope.Tables {

public const string BUDGETS = """
CREATE TABLE IF NOT EXISTS budgets (
    `id` INT PRIMARY KEY,
    `label` TEXT UNIQUE NOT NULL)
""";

public const string ACCOUNTS = """
CREATE TABLE IF NOT EXISTS accounts (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `number` TEXT,
    `description` TEXT,
    `balance` DOUBLE,
    `type` INT)
    """;

public const string TRANSACTIONS = """
CREATE TABLE IF NOT EXISTS transactions (
    `id` INT PRIMARY KEY,
    `label` TEXT NOT NULL,
    `description` TEXT,
    `direction` INT NOT NULL,
    `amount` DOUBLE NOT NULL,
    `account_id` INT NOT NULL,
    `parent_transaction_id` INT,
    `date` TIMESTAMP NOT NULL,
    FOREIGN KEY (`parent_transaction_id`) REFERENCES `transactions`(`id`),
    FOREIGN KEY (`account_id`) REFERENCES `accounts`(`id`))
    """;
}
