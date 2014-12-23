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
    }

    [CCode (cheader_filename = "locale.h", cname = "localeconv")]
    public lconv* localeconv ();

    [CCode(cheader_filename = "monetary.h", cname = "strfmon")]
    static ssize_t strfmon(char[] s, string format, double data);
}
