class DateTimeUtils {
  static String formatDateTime(DateTime dateTime) {
    return dateTime.toString();
  }

  static DateTime parseDateTime(String dateTime) {
    return DateTime.parse(dateTime);
  }
}
