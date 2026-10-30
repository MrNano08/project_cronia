/// Compact, local recurrence rule. Occurrences are generated only for the
/// requested range; no duplicate task rows are written to SharedPreferences.
enum RecurrenceFrequency { daily, weekdays, weekly, monthly, yearly }
enum RecurrenceEnd { never, onDate, afterCount }
enum MonthlyPattern { dayOfMonth, weekdayPosition }
enum RecurrenceEditScope { occurrence, thisAndFollowing, series }

class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;
  final List<int> weekdays; // DateTime weekday: Monday=1 ... Sunday=7.
  final MonthlyPattern monthlyPattern;
  final int dayOfMonth;
  final int weekdayPosition; // 1..4, or -1 for last.
  final int monthlyWeekday;
  final DateTime startDate;
  final RecurrenceEnd end;
  final DateTime? endDate;
  final int? occurrenceCount;
  final List<String> exceptions;
  final List<String> completedDates;
  final List<String> cancelledDates;
  final Map<String, Map<String, dynamic>> occurrenceOverrides;

  const RecurrenceRule({required this.frequency, this.interval = 1, this.weekdays = const [], this.monthlyPattern = MonthlyPattern.dayOfMonth, this.dayOfMonth = 1, this.weekdayPosition = 1, this.monthlyWeekday = DateTime.monday, required this.startDate, this.end = RecurrenceEnd.never, this.endDate, this.occurrenceCount, this.exceptions = const [], this.completedDates = const [], this.cancelledDates = const [], this.occurrenceOverrides = const {}});

  Map<String, dynamic> toJson() => {'frequency': frequency.name, 'interval': interval, 'weekdays': weekdays, 'monthlyPattern': monthlyPattern.name, 'dayOfMonth': dayOfMonth, 'weekdayPosition': weekdayPosition, 'monthlyWeekday': monthlyWeekday, 'startDate': startDate.toIso8601String(), 'end': end.name, 'endDate': endDate?.toIso8601String(), 'occurrenceCount': occurrenceCount, 'exceptions': exceptions, 'completedDates': completedDates, 'cancelledDates': cancelledDates, 'occurrenceOverrides': occurrenceOverrides};
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(frequency: RecurrenceFrequency.values.firstWhere((e) => e.name == json['frequency'], orElse: () => RecurrenceFrequency.daily), interval: ((json['interval'] as num?)?.toInt() ?? 1).clamp(1, 365).toInt(), weekdays: (json['weekdays'] as List? ?? []).whereType<num>().map((e) => e.toInt()).where((e) => e >= 1 && e <= 7).toSet().toList()..sort(), monthlyPattern: MonthlyPattern.values.firstWhere((e) => e.name == json['monthlyPattern'], orElse: () => MonthlyPattern.dayOfMonth), dayOfMonth: ((json['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 31).toInt(), weekdayPosition: (json['weekdayPosition'] as num?)?.toInt() ?? 1, monthlyWeekday: ((json['monthlyWeekday'] as num?)?.toInt() ?? DateTime.monday).clamp(1, 7).toInt(), startDate: DateTime.parse(json['startDate'] as String), end: RecurrenceEnd.values.firstWhere((e) => e.name == json['end'], orElse: () => RecurrenceEnd.never), endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate'] as String), occurrenceCount: (json['occurrenceCount'] as num?)?.toInt(), exceptions: (json['exceptions'] as List? ?? []).whereType<String>().toList(), completedDates: (json['completedDates'] as List? ?? []).whereType<String>().toList(), cancelledDates: (json['cancelledDates'] as List? ?? []).whereType<String>().toList(), occurrenceOverrides: (json['occurrenceOverrides'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))));

  RecurrenceRule copyWith({RecurrenceEnd? end, DateTime? endDate, int? occurrenceCount, List<String>? completedDates, List<String>? cancelledDates, List<String>? exceptions, Map<String, Map<String, dynamic>>? occurrenceOverrides}) => RecurrenceRule(frequency: frequency, interval: interval, weekdays: weekdays, monthlyPattern: monthlyPattern, dayOfMonth: dayOfMonth, weekdayPosition: weekdayPosition, monthlyWeekday: monthlyWeekday, startDate: startDate, end: end ?? this.end, endDate: endDate ?? this.endDate, occurrenceCount: occurrenceCount ?? this.occurrenceCount, exceptions: exceptions ?? this.exceptions, completedDates: completedDates ?? this.completedDates, cancelledDates: cancelledDates ?? this.cancelledDates, occurrenceOverrides: occurrenceOverrides ?? this.occurrenceOverrides);
}

class RecurrenceEngine {
  static List<DateTime> between(RecurrenceRule rule, DateTime from, DateTime to, {int limit = 500}) {
    if (to.isBefore(from) || limit <= 0) return [];
    final start = DateTime(rule.startDate.year, rule.startDate.month, rule.startDate.day);
    final end = DateTime(rule.endDate?.year ?? 9999, rule.endDate?.month ?? 12, rule.endDate?.day ?? 31);
    final low = DateTime(from.year, from.month, from.day);
    final high = DateTime(to.year, to.month, to.day);
    final output = <DateTime>[];
    var generated = 0;
    // Scan only the requested window unless count termination requires knowing
    // how many matching occurrences have already existed.
    final scanStart = rule.end == RecurrenceEnd.afterCount || !low.isAfter(start) ? start : low;
    for (var day = scanStart; !day.isAfter(high) && !day.isAfter(end); day = _nextCivilDay(day)) {
      if (!_matches(rule, day)) continue;
      generated++;
      if (rule.end == RecurrenceEnd.afterCount && generated > (rule.occurrenceCount ?? 0)) break;
      final key = _key(day);
      if (rule.exceptions.contains(key) || rule.completedDates.contains(key) || rule.cancelledDates.contains(key) || day.isBefore(low)) continue;
      output.add(day);
      if (output.length >= limit) break;
    }
    return output;
  }

  static List<DateTime> next(RecurrenceRule rule, {int count = 5, DateTime? after}) {
    final from = after ?? DateTime.now();
    return between(rule, from, DateTime(from.year + 20, from.month, from.day), limit: count);
  }

  static String key(DateTime d) => _key(d);
  static String occurrenceId(String seriesId, DateTime date) => '$seriesId@${_key(date)}';
  static int countThrough(RecurrenceRule rule, DateTime through) {
    final start = DateTime(rule.startDate.year, rule.startDate.month, rule.startDate.day);
    final end = DateTime(through.year, through.month, through.day);
    var count = 0;
    for (var day = start; !day.isAfter(end); day = _nextCivilDay(day)) {
      if (_matches(rule, day)) count++;
    }
    return count;
  }

  static bool _matches(RecurrenceRule r, DateTime d) {
    final start = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
    switch (r.frequency) {
      case RecurrenceFrequency.daily:
        return _civilDays(d, start) % r.interval == 0;
      case RecurrenceFrequency.weekdays:
        return d.weekday <= DateTime.friday && _civilDays(d, start) >= 0;
      case RecurrenceFrequency.weekly:
        final weekStart = DateTime.utc(start.year, start.month, start.day).subtract(Duration(days: start.weekday - 1));
        final week = DateTime.utc(d.year, d.month, d.day).difference(weekStart).inDays ~/ 7;
        final days = r.weekdays.isEmpty ? [start.weekday] : r.weekdays;
        return week >= 0 && week % r.interval == 0 && days.contains(d.weekday);
      case RecurrenceFrequency.monthly:
        final months = (d.year - start.year) * 12 + d.month - start.month;
        if (months < 0 || months % r.interval != 0) return false;
        if (r.monthlyPattern == MonthlyPattern.dayOfMonth) {
          return d.day == (r.dayOfMonth > DateTime(d.year, d.month + 1, 0).day ? DateTime(d.year, d.month + 1, 0).day : r.dayOfMonth);
        }
        return d.weekday == r.monthlyWeekday && _position(d) == r.weekdayPosition;
      case RecurrenceFrequency.yearly:
        if ((d.year - start.year) % r.interval != 0 || d.month != start.month) return false;
        return d.day == (start.day > DateTime(d.year, d.month + 1, 0).day ? DateTime(d.year, d.month + 1, 0).day : start.day);
    }
  }
  static int _position(DateTime d) => DateTime(d.year, d.month, d.day + 7).month == d.month ? ((d.day - 1) ~/ 7) + 1 : -1;
  static DateTime _nextCivilDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
  static int _civilDays(DateTime date, DateTime from) => DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  static String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
