namespace Envelope.Util {

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

        if (regex_parse_currency == null) {
            initialize_currency_regex ();
        }

        double result;

        // replace all non-currency characters (except . and separator)
        var sanitized = regex_parse_currency.replace_literal(amount, -1, 0, "");

        debug ("parsing %s", sanitized);

        char *r;
        result = Monetary.strtod (sanitized, &r);

        //if (!double.try_parse (sanitized, out result)) {
        //    throw new ParseError.INVALID ("cannot parse %s".printf (amount));
        //}

        return result;
    }

    // regular expression to strip everything but numbers and currency-specific characters
    private static Regex regex_parse_currency;

    // initializer for the currency regexp
    private static void initialize_currency_regex () {

        Monetary.lconv *locale_info = Monetary.localeconv ();

        try {
            debug ("decimal point: %c", *(locale_info->decimal_point));

            regex_parse_currency = new Regex ("[^0-9\\%c]*".printf (*(locale_info->decimal_point)));
        }
        catch (RegexError err) {
            error (err.message);
        }
    }
}
