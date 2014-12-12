namespace Envelope.Util {

    static const string CURRENCY_FORMAT = "%11n";

    public static string format_currency (double amount) {
        char buffer[20];

        strfmon(buffer, CURRENCY_FORMAT, amount);
        
        return (string) buffer;
    }
}
