namespace Envelope.Util.String {

    public static const string ELLIPSIS = "\u2026";
    private static char* currency_symbol = null;

    public errordomain ParseError {
        INVALID
    }

    public static string ellipsize (string input) {
        return "%s%s".printf (input, ELLIPSIS);
    }

    public static string format_currency (double amount, bool currency_symbol = true) {

        string format = currency_symbol ? "%11n" : "%!11n";

        char[] buffer = new char[double.DTOSTR_BUF_SIZE];
        Monetary.strfmon(buffer, format, amount);

        return ((string) buffer).strip ();
    }

    public char* get_currency_symbol () {
        if (currency_symbol != null) {
            return currency_symbol;
        }

        Monetary.lconv *locale_info = Monetary.localeconv ();
        currency_symbol = locale_info->currency_symbol;

        return currency_symbol;
    }

    public static double parse_currency (string amount) throws ParseError {

        if (regex_parse_currency == null) {
            initialize_currency_regex ();
        }

        double result;

        // replace all non-currency characters (except . and separator)
        string sanitized = amount;
        try {
            sanitized = regex_parse_currency.replace_literal(amount, -1, 0, "");
        }
        catch (RegexError err) {
            error ("error occured while sanitizing input string '%s' (%s))", amount, err.message);
        }

        char *r;
        result = Monetary.strtod (sanitized, &r);

        return result;
    }

    // regular expression to strip everything but numbers and currency-specific characters
    private static Regex regex_parse_currency;

    // initializer for the currency regexp
    private static void initialize_currency_regex () {

        Monetary.lconv *locale_info = Monetary.localeconv ();

        try {
            debug ("decimal point: %c", *(locale_info->decimal_point));

            regex_parse_currency = new Regex ("[^0-9\\%c\\-]*".printf (*(locale_info->decimal_point)));
        }
        catch (RegexError err) {
            error (err.message);
        }
    }
}
