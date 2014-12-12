namespace Envelope.Util {
  [CCode(cheader_filename = "monetary.h", cname = "strfmon")]
  static ssize_t strfmon(char[] s, string format, double data);
}
