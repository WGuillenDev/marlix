// Keep the minimum age in sync with the Supabase signup trigger.
const minimumAge = 18;

bool isOldEnough(DateTime birthDate, DateTime today) {
  final birthday = DateTime(birthDate.year + minimumAge, birthDate.month, birthDate.day);
  return !birthday.isAfter(DateTime(today.year, today.month, today.day));
}

DateTime? parseBirthDate(String text) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final [day, month, year] = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  final date = DateTime(year, month, day);
  // DateTime normalizes invalid calendar dates, so validate the round trip.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
