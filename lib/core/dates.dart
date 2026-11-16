/// Tanggal transaksi disimpan sebagai 'yyyy-MM-dd' tanpa jam, supaya
/// perbandingan rentang di SQLite dan di Dart selalu sama.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String toDbDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime fromDbDate(String s) => dateOnly(DateTime.parse(s));

/// Selisih hari kalender, aman terhadap pergeseran jam (DST).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Jumlah bulan penuh. 15 Jan -> 15 Okt = 9, 15 Jan -> 14 Okt = 8.
int wholeMonthsBetween(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day < from.day) months -= 1;
  return months;
}

/// Rentang tanggal inklusif di kedua ujung.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = dateOnly(start),
      end = dateOnly(end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }
}

class MonthRef implements Comparable<MonthRef> {
  const MonthRef(this.year, this.month);
  factory MonthRef.of(DateTime d) => MonthRef(d.year, d.month);

  final int year;
  final int month;

  MonthRef get previous => MonthRef.of(DateTime(year, month - 1));
  MonthRef get next => MonthRef.of(DateTime(year, month + 1));
  DateRange get range =>
      DateRange(DateTime(year, month), DateTime(year, month + 1, 0));
  int get _index => year * 12 + month - 1;

  @override
  int compareTo(MonthRef other) => _index.compareTo(other._index);
  @override
  bool operator ==(Object other) => other is MonthRef && other._index == _index;
  @override
  int get hashCode => _index;
}

const monthNamesId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const shortMonthNamesId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

enum PeriodKind {
  week('minggu'),
  month('bulan'),
  year('tahun');

  const PeriodKind(this.noun);

  /// Huruf kecil, untuk kalimat: "bulan ini", "minggu lalu".
  final String noun;

  String get nounCapitalized => '${noun[0].toUpperCase()}${noun.substring(1)}';
}

/// Satu periode tampilan: minggu (Senin-Minggu), bulan, atau tahun kalender.
class Period {
  const Period._(this.kind, this.start, this.end);

  factory Period.containing(PeriodKind kind, DateTime date) {
    final d = dateOnly(date);
    switch (kind) {
      case PeriodKind.week:
        final start = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        return Period._(
          kind,
          start,
          DateTime(start.year, start.month, start.day + 6),
        );
      case PeriodKind.month:
        return Period._(
          kind,
          DateTime(d.year, d.month),
          DateTime(d.year, d.month + 1, 0),
        );
      case PeriodKind.year:
        return Period._(kind, DateTime(d.year), DateTime(d.year, 12, 31));
    }
  }

  final PeriodKind kind;
  final DateTime start;
  final DateTime end;

  DateRange get range => DateRange(start, end);

  Period get previous =>
      Period.containing(kind, DateTime(start.year, start.month, start.day - 1));

  Period get next =>
      Period.containing(kind, DateTime(end.year, end.month, end.day + 1));

  bool contains(DateTime d) => range.contains(d);

  /// Hari ini jika berada di dalam periode, jika tidak ujung periode terdekat.
  DateTime referenceDate(DateTime today) {
    final t = dateOnly(today);
    if (t.isBefore(start)) {
      return start;
    }
    if (t.isAfter(end)) {
      return end;
    }
    return t;
  }

  String get label {
    switch (kind) {
      case PeriodKind.month:
        return '${monthNamesId[start.month - 1]} ${start.year}';
      case PeriodKind.year:
        return '${start.year}';
      case PeriodKind.week:
        final s = shortMonthNamesId[start.month - 1];
        final e = shortMonthNamesId[end.month - 1];
        if (start.year != end.year) {
          return '${start.day} $s ${start.year} – ${end.day} $e ${end.year}';
        }
        if (start.month != end.month) {
          return '${start.day} $s – ${end.day} $e ${end.year}';
        }
        return '${start.day} – ${end.day} $e ${end.year}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);
}
