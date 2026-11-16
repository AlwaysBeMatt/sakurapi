import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../data/finance_repository.dart' show TransactionSort;
import '../domain/models/money_transaction.dart';

class TxFilter {
  const TxFilter({
    this.query = '',
    this.types = const {},
    this.categoryIds = const {},
    this.accountId,
    this.from,
    this.to,
    this.sort = TransactionSort.newest,
  });

  final String query;
  final Set<TransactionType> types;
  final Set<String> categoryIds;
  final String? accountId;
  final DateTime? from;
  final DateTime? to;
  final TransactionSort sort;

  /// Jumlah kelompok filter yang aktif (pencarian dan urutan tidak dihitung).
  int get activeCount =>
      (types.isEmpty ? 0 : 1) +
      (categoryIds.isEmpty ? 0 : 1) +
      (accountId == null ? 0 : 1) +
      (from == null && to == null ? 0 : 1);

  bool get isFiltering => query.trim().isNotEmpty || activeCount > 0;

  TxFilter copyWith({
    String? query,
    Set<TransactionType>? types,
    Set<String>? categoryIds,
    String? accountId,
    bool clearAccount = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    TransactionSort? sort,
  }) => TxFilter(
    query: query ?? this.query,
    types: types ?? this.types,
    categoryIds: categoryIds ?? this.categoryIds,
    accountId: clearAccount ? null : (accountId ?? this.accountId),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    sort: sort ?? this.sort,
  );

  /// Menyaring lalu mengurutkan. Fungsi murni, jadi mudah diuji.
  List<MoneyTransaction> apply(Iterable<MoneyTransaction> all) {
    final q = query.trim().toLowerCase();
    final result = all.where((t) {
      if (q.isNotEmpty &&
          !t.title.toLowerCase().contains(q) &&
          !(t.note ?? '').toLowerCase().contains(q)) {
        return false;
      }
      if (types.isNotEmpty && !types.contains(t.type)) {
        return false;
      }
      if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
        return false;
      }
      if (accountId != null &&
          t.accountId != accountId &&
          t.toAccountId != accountId) {
        return false;
      }
      final d = dateOnly(t.date);
      if (from != null && d.isBefore(dateOnly(from!))) {
        return false;
      }
      if (to != null && d.isAfter(dateOnly(to!))) {
        return false;
      }
      return true;
    }).toList();

    int byCreatedDesc(MoneyTransaction a, MoneyTransaction b) =>
        b.createdAt.compareTo(a.createdAt);

    result.sort((a, b) {
      final int c;
      switch (sort) {
        case TransactionSort.newest:
          c = b.date.compareTo(a.date);
          return c != 0 ? c : byCreatedDesc(a, b);
        case TransactionSort.oldest:
          c = a.date.compareTo(b.date);
          return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
        case TransactionSort.largest:
          c = b.amount.compareTo(a.amount);
          return c != 0 ? c : b.date.compareTo(a.date);
        case TransactionSort.smallest:
          c = a.amount.compareTo(b.amount);
          return c != 0 ? c : b.date.compareTo(a.date);
      }
    });
    return result;
  }
}

class TxFilterNotifier extends Notifier<TxFilter> {
  @override
  TxFilter build() => const TxFilter();

  void set(TxFilter filter) {
    state = filter;
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSort(TransactionSort sort) {
    state = state.copyWith(sort: sort);
  }

  /// Menghapus semua filter dan pencarian, urutan dipertahankan.
  void clearAll() {
    state = TxFilter(sort: state.sort);
  }
}

final txFilterProvider = NotifierProvider<TxFilterNotifier, TxFilter>(
  TxFilterNotifier.new,
);
