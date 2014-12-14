namespace Envelope.Util {

    static const string ELLIPSIS = "\u2026";

    public static string ellipsize (string input) {
        return "%s%s".printf (input, ELLIPSIS);
    }

    public static string format_currency (double amount) {
        char buffer[20];
        Monetary.strfmon(buffer, "%11n", amount);
        return (string) buffer;
    }
}
