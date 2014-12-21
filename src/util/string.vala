namespace Envelope.Util {

    static const string ELLIPSIS = "\u2026";

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
        double result;

        var sanitized = amount.replace ("$", "").replace (",", "").replace (" ", "");

        if (!double.try_parse (sanitized, out result)) {
            throw new ParseError.INVALID ("cannot parse %s".printf (amount));
        }

        return result;
    }
}
