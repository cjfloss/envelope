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

namespace Envelope.Util.Date {
    /**
     * Get start and end dates for the specified month and year
     *
     * @param month the month number (starting at 1)
     * @param year the year
     * @param start the output start date of the month
     * @param end the output ending date of the month
     */
    public void get_month_boundaries (int month, int year, out DateTime start,
                                      out DateTime end) {
        start = new DateTime.local (year, month, 1, 0, 0, 0);
        end = new DateTime.local (year, month,
                                  GLib.Date.get_days_in_month (
                                      (DateMonth) month,
                                      (DateYear) year),
                                      23, 59, 59);
    }

    /**
     * Get the current year and month
     *
     * @param month the output month number
     * @param year the output year number
     */
    public void get_year_month (out int month, out int year) {
        var now = new DateTime.now_local ();

        month = now.get_month ();
        year = now.get_year ();
    }

    /**
     * Get the month and year numbers for the specified number of months before now
     *
     * @param ago the number of months before now
     * @param month the output month number
     * @param year the output year number
     */
    public void months_ago (int ago, out int month, out int year) {
        var months_ago = new DateTime.now_local ().add_months (-ago);

        month = months_ago.get_month ();
        year = months_ago.get_year ();

        debug ("months_ago (%d): %d-%d", ago, year, month);
    }

    /**
     * Get the date for tomorrow
     *
     * @param tomorrow the output date for tomorrow
     */
    public void tomorrow (out DateTime tomorrow) {
        var dt = new DateTime.now_local ().add_days (1);
        tomorrow = new DateTime.local (dt.get_year (), dt.get_month (),
                                       dt.get_day_of_month (), 0, 0, 0);
    }
}
