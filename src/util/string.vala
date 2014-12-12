namespace Envelope.Util {

    static const string ELLIPSIS = "\u2026";

    public static string ellipsize (string input) {
        return "%s%s".printf (input, ELLIPSIS);
    }
}
