/* Copyright 2014 Nicolas Laplante
*            2018 Cleiton Floss
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

namespace Envelope.Database {
    private const string ACCOUNTS = """
        CREATE TABLE IF NOT EXISTS accounts (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT,
            `number` TEXT NOT NULL,
            `description` TEXT,
            `balance` DOUBLE,
            `type` INT);
    """;

    private const string TRANSACTIONS = """
        CREATE TABLE IF NOT EXISTS transactions (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT,
            `label` TEXT NOT NULL,
            `description` TEXT,
            `direction` INT NOT NULL,
            `amount` DOUBLE NOT NULL,
            `account_id` INT NOT NULL,
            `category_id` INT,
            `parent_transaction_id` INT,
            `date` TIMESTAMP NOT NULL,
        FOREIGN KEY (`parent_transaction_id`)
            REFERENCES `transactions`(`id`)
            ON UPDATE CASCADE
            ON DELETE CASCADE,
        FOREIGN KEY (`category_id`)
            REFERENCES `categories`(`id`)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
        FOREIGN KEY (`account_id`)
            REFERENCES `accounts`(`id`)
            ON UPDATE CASCADE
            ON DELETE CASCADE);
    """;

    private const string CATEGORIES = """
        CREATE TABLE IF NOT EXISTS categories (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT,
            `name` TEXT NOT NULL,
            `description` TEXT,
            `parent_category_id` INT,
        FOREIGN KEY (`parent_category_id`)
            REFERENCES `categories`(`id`)
            ON UPDATE CASCADE
            ON DELETE CASCADE);
    """;

    private const string MONTHLY_CATEGORIES = """
        CREATE TABLE IF NOT EXISTS categories_budgets (
            `category_id` INTEGER NOT NULL,
            `year` INTEGER NOT NULL,
            `month` INTEGER NOT NULL,
            `amount_budgeted` DOUBLE,
        PRIMARY KEY (`category_id`, `year`, `month`),
        FOREIGN KEY (`category_id`)
            REFERENCES `categories`(`id`)
            ON UPDATE CASCADE
            ON DELETE CASCADE
        ) WITHOUT ROWID;
    """;

    private const string MONTHLY_BUDGET = """
        CREATE TABLE IF NOT EXISTS monthly_budgets (
            `month` INTEGER NOT NULL,
            `year` INTEGER NOT NULL,
            `outflow` DOUBLE,
            `inflow` DOUBLE,
        PRIMARY KEY (`month`, `year`)
        ) WITHOUT ROWID;
    """;

    private const string SQL_CATEGORY_COUNT = """
        SELECT COUNT(*) AS category_count
        FROM categories;
    """;

    private const string SQL_INSERT_CATEGORY_FOR_NAME = """
        INSERT INTO `categories`
            (`name`)
        VALUES
            (?);
    """;

    private const string SQL_SET_CATEGORY_BUDGET = """
        INSERT INTO `categories_budgets`
            (`category_id`, `year`, `month`, `amount_budgeted`)
        VALUES
            (?, ?, ?, ?);
    """;

    private const string SQL_UPDATE_CATEGORY_BUDGET = """
        UPDATE `categories_budgets`
        SET `amount_budgeted` = ?
        WHERE `category_id` = ?
            AND `year` = ?
            AND `month` = ?;
    """;

    private const string SQL_CHECK_CATEGORY_BUDGET_SET = """
        SELECT COUNT(*) AS size
        FROM categories_budgets
        WHERE category_id = ?
        AND year = ?
        AND month = ?;
    """;

    private const string SQL_DELETE_TRANSACTION = """
        DELETE FROM `transactions`
        WHERE `id` = ?;
    """;

    private const string SQL_GET_TRANSACTION_BY_ID = """
        SELECT * FROM `transactions`
        WHERE `id` = ?;
    """;

    private const string SQL_GET_UNCATEGORIZED_TRANSACTIONS = """
        SELECT * FROM `transactions`
        WHERE `category_id` IS NULL;
    """;

    private const string SQL_RENAME_ACCOUNT = """
        UPDATE `accounts`
        SET `number` = ?
        WHERE `id` = ?;
    """;

    private const string SQL_DELETE_ACCOUNT = """
        DELETE FROM `accounts`
        WHERE `id` = ?;
    """;

    private const string SQL_UPDATE_ACCOUNT_BALANCE = """
        UPDATE `accounts`
        SET `balance` = ?
        WHERE `id` = ?;
    """;

    private const string SQL_LOAD_ACCOUNT_TRANSACTIONS = """
        SELECT * FROM `transactions`
        WHERE `account_id` = ?
        ORDER BY `date` DESC;
    """;

    private const string SQL_DELETE_ACCOUNT_TRANSACTIONS = """
        DELETE FROM `transactions` WHERE `account_id` = ?;""";

    private const string SQL_GET_UNIQUE_PAYEES = """
        SELECT `label`, COUNT(`label`) as `number`
            FROM `transactions`
            GROUP BY `label`
            ORDER BY `number`
                DESC, `label` ASC;
    """;

    private const string SQL_LOAD_CATEGORIES = """
        SELECT `c`.*, `cb`.`year`, `cb`.`month`, `cb`.`amount_budgeted`
            FROM `categories` `c`
            LEFT JOIN `categories_budgets` `cb` ON `cb`.`category_id` = `c`.`id`
            AND `cb`.`year` = strftime('%Y', 'now')
            AND `cb`.`month` = strftime('%m', 'now')
            ORDER BY `c`.`name` ASC;
    """;

    private const string SQL_LOAD_CHILD_CATEGORIES = """
        SELECT * FROM `categories` WHERE `parent_category_id` = ? ORDER BY `name` ASC;""";

    private const string SQL_DELETE_CATEOGRY = """
        DELETE FROM `categories` WHERE `id` = ?;""";

    private const string SQL_UPDATE_CATEGORY = """
        UPDATE `categories` SET `name` = ?, `description` = ?, `parent_category_id` = ? WHERE `id` = ?;""";

    private const string SQL_CATEGORIZE_ALL_FOR_PAYEE = """
        UPDATE `transactions` SET `category_id` = ? WHERE `label` = ?;""";

    private const string SQL_LOAD_CURRENT_TRANSACTIONS = """
        SELECT * FROM transactions
        WHERE date(date, 'unixepoch')
            BETWEEN date('now', 'start of month')
            AND date('now', 'start of month', '+1 month', '-1 days');
    """;

    private const string SQL_LOAD_TRANSACTIONS_FOR_MONTH = """
        SELECT t.*, c.*, cb.* FROM transactions t
        LEFT JOIN categories c
        ON c.id = t.category_id
        LEFT JOIN categories_budgets cb
        ON cb.category_id = t.category_id AND cb.year = ? and cb.month = ?
        WHERE date(t.date, 'unixepoch')
            BETWEEN date(?, 'start of month')
            AND date(?, 'start of month', '+1 month', '-1 days')
        ORDER BY t.date DESC;
    """;

    private const string SQL_LOAD_CURRENT_TRANSACTIONS_FOR_CATEGORY = """
        SELECT * FROM transactions
        WHERE date(date, 'unixepoch')
            BETWEEN date('now', 'start of month')
            AND date('now', 'start of month', '+1 month', '-1 days')
            AND category_id = ?;
    """;

    private const string SQL_LOAD_CURRENT_UNCATEGORIZED_TRANSACTIONS = """
        SELECT * FROM transactions
        WHERE date (date, 'unixepoch')
            BETWEEN date('now', 'start of month')
            AND date('now', 'start of month', '+1 month', '-1 days')
            AND category_id IS NULL;
    """;

    private const string SQL_INSERT_CATEGORY = """
        INSERT INTO `categories`
        (`name`, `description`, `parent_category_id`)
        VALUES
        (?, ?, ?);
    """;

    private const string SQL_UPDATE_TRANSACTION = """
        UPDATE `transactions` SET
        label = ?,
        description = ?,
        direction = ?,
        amount = ?,
        account_id = ?,
        category_id = ?,
        parent_transaction_id = ?,
        date = ?
        WHERE id = ?;
    """;

    private const string SQL_INSERT_TRANSACTION = """
        INSERT INTO `transactions`
        (`label`, `description`, `amount`, `direction`, `account_id`, `parent_transaction_id`, `date`, `category_id`)
        VALUES
        (?, ?, ?, ?, ?, ?, ?, ?);
    """;

    private const string SQL_LOAD_ACCOUNT_BY_ID = """
        SELECT * FROM `accounts` WHERE `id` = ?;""";

    private const string SQL_LOAD_ALL_ACCOUNTS = """
        SELECT * FROM `accounts` ORDER BY `number`;""";

    private const string SQL_INSERT_ACCOUNT = """
        INSERT INTO `accounts`
        (`number`, `description`, `balance`, `type`)
        VALUES
        (?, ?, ?, ?);
        """;
}
