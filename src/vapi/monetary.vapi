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

namespace Monetary {

    [CCode (cheader_filename = "locale.h", cname = "struct lconv", has_type_id = false)]
    [SimpleType]
    public struct lconv {
      char* decimal_point;
      char* mon_decimal_point;
      char* thousands_sep;
      char* mon_thousands_sep;
      char* grouping;
      char* mon_grouping;
      char* int_frac_digits;
      char* frac_digits;
      char* currency_symbol;
      char* int_currency_symbol;
      char p_cs_precedes;
      char n_cs_precedes;
      char p_sep_by_space;
      char n_sep_by_space;
      char* positive_sign;
      char* negative_sign;
      char p_sign_posn;
      char n_sign_posn;
    }

    [CCode (cheader_filename = "locale.h", cname = "localeconv")]
    public lconv* localeconv ();

    [CCode(cheader_filename = "monetary.h", cname = "strfmon")]
    static ssize_t strfmon(char[] s, string format, double data);

    [CCode (cname = "strtod")]
    static double strtod (string input, char** last);
}
