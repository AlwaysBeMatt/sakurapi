import 'dart:math';

import '../../core/dates.dart';
import '../../core/money.dart';
import 'money_transaction.dart';

enum RecurrenceFrequency {
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  const RecurrenceFrequency(this.label);
  final String label;
}

/// Aturan yang mencatat pemasukan atau pengeluaran secara otomatis.
/// [nextDate] adalah tanggal transaksi berikutnya yang belum dicatat.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    required this.nextDate,
    required this.createdAt,
    this.title = '',
    this.endDate,
    this.note,
    this.active = true,
  });

  final String id;
  final TransactionType type;
  final int amount;
  final String title;
  final String categoryId;
  final String accountId;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime nextDate;
  final DateTime? endDate;
  final String? note;
  final bool active;
  final DateTime createdAt;

  /// Tanggal kemunculan setelah [nextDate]. Bulanan dan tahunan mengikuti hari
  /// pada [startDate], dan jatuh di akhir bulan bila bulannya lebih pendek.
  DateTime get followingDate {
    switch (frequency) {
      case RecurrenceFrequency.weekly:
        return DateTime(nextDate.year, nextDate.month, nextDate.day + 7);
      case RecurrenceFrequency.monthly:
        return _anchored(nextDate.year, nextDate.month + 1);
      case RecurrenceFrequency.yearly:
        return _anchored(nextDate.year + 1, nextDate.month);
    }
  }

  DateTime _anchored(int year, int month) {
    final first = DateTime(year, month, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, min(startDate.day, lastDay));
  }

  /// Sudah melewati tanggal berakhir, jadi tidak ada lagi yang dicatat.
  bool get isFinished => endDate != null && nextDate.isAfter(endDate!);

  RecurringRule advance() => copyWith(nextDate: followingDate);

  /// Melewati kemunculan yang sudah lewat, untuk aturan yang diaktifkan
  /// kembali setelah dijeda. Periode yang dijeda tidak dicatat mundur.
  RecurringRule skipTo(DateTime today) {
    final t = dateOnly(today);
    var rule = this;
    var guard = 0;
    while (rule.nextDate.isBefore(t) && guard < 2000) {
      rule = rule.advance();
      guard++;
    }
    return rule;
  }

  /// [isNew] true saat membuat aturan: tanggal mulai dibatasi supaya satu
  /// salah ketik tidak mencatat ratusan transaksi sekaligus.
  String? validate({required DateTime today, bool isNew = true}) {
    if (type == TransactionType.transfer) {
      return 'Transaksi berulang hanya untuk pemasukan atau pengeluaran.';
    }
    if (amount <= 0) {
      return 'Nominal harus lebih dari Rp0.';
    }
    if (amount > Money.maxAmount) {
      return 'Nominal terlalu besar.';
    }
    if (title.length > 100) {
      return 'Nama transaksi maksimal 100 karakter.';
    }
    if ((note?.length ?? 0) > 500) {
      return 'Catatan maksimal 500 karakter.';
    }
    final t = dateOnly(today);
    if (startDate.isBefore(DateTime(2000))) {
      return 'Tanggal mulai tidak valid.';
    }
    if (isNew) {
      if (startDate.isBefore(DateTime(t.year, t.month, t.day - 400))) {
        return 'Tanggal mulai tidak boleh lebih dari 13 bulan ke belakang.';
      }
      if (startDate.isAfter(DateTime(t.year + 1, t.month, t.day))) {
        return 'Tanggal mulai tidak boleh lebih dari satu tahun ke depan.';
      }
    }
    if (endDate != null && endDate!.isBefore(startDate)) {
      return 'Tanggal berakhir tidak boleh sebelum tanggal mulai.';
    }
    return null;
  }

  RecurringRule copyWith({
    int? amount,
    String? title,
    String? categoryId,
    String? accountId,
    DateTime? nextDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? note,
    bool clearNote = false,
    bool? active,
  }) => RecurringRule(
    id: id,
    type: type,
    amount: amount ?? this.amount,
    title: title ?? this.title,
    categoryId: categoryId ?? this.categoryId,
    accountId: accountId ?? this.accountId,
    frequency: frequency,
    startDate: startDate,
    nextDate: nextDate ?? this.nextDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    note: clearNote ? null : (note ?? this.note),
    active: active ?? this.active,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'title': title,
    'category_id': categoryId,
    'account_id': accountId,
    'frequency': frequency.name,
    'start_date': toDbDate(startDate),
    'next_date': toDbDate(nextDate),
    'end_date': endDate == null ? null : toDbDate(endDate!),
    'note': note,
    'active': active ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
    id: m['id']! as String,
    type: TransactionType.values.byName(m['type']! as String),
    amount: m['amount']! as int,
    title: (m['title'] as String?) ?? '',
    categoryId: m['category_id']! as String,
    accountId: m['account_id']! as String,
    frequency: RecurrenceFrequency.values.byName(m['frequency']! as String),
    startDate: fromDbDate(m['start_date']! as String),
    nextDate: fromDbDate(m['next_date']! as String),
    endDate: switch (m['end_date']) {
      final String s => fromDbDate(s),
      _ => null,
    },
    note: m['note'] as String?,
    active: m['active'] == 1,
    createdAt: DateTime.parse(m['created_at']! as String),
  );
}