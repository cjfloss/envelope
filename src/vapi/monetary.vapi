[CCode (cheader_filename = "locale.h")]
namespace Monetary {

    [CCode (cname = "struct lconv", has_type_id = false)]
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
}
