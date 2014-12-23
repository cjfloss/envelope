namespace Envelope.Util {

    private static Regex REGEX_NON_AMOUNT;

    public static const string ELLIPSIS = "\u2026";

    public errordomain ParseError {
        INVALID
    }

    public static string ellipsize (string input) {
        return "%s%s".printf (input, ELLIPSIS);
    }

    public static string format_currency (double amount) {
        char[] buffer = new char[double.DTOSTR_BUF_SIZE];
        Monetary.strfmon(buffer, "%11n", amount);
        return ((string) buffer).strip ();
    }

    public static double parse_currency (string amount) throws ParseError {

        if (REGEX_NON_AMOUNT == null) {

            Monetary.lconv *locale_info = Monetary.localeconv ();
            
            try {
                REGEX_NON_AMOUNT = new Regex ("[^0-9\\%c]*".printf (*(locale_info->decimal_point)));
            }
            catch (RegexError err) {
                error (err.message);
            }
        }

        double result;

        // replace all non-currency characters (except . and separator)
        var sanitized = REGEX_NON_AMOUNT.replace_literal(amount, -1, 0, "").strip ();

        if (!double.try_parse (sanitized, out result)) {
            throw new ParseError.INVALID ("cannot parse %s".printf (amount));
        }

        return result;
    }
}
