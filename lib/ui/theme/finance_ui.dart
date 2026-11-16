import 'package:flutter/material.dart';

import '../../domain/models/money_transaction.dart';

/// Kunci ikon dari database dipetakan ke IconData di sini.
IconData iconForKey(String key) => switch (key) {
  'restaurant' => Icons.restaurant,
  'bus' => Icons.directions_bus,
  'basket' => Icons.shopping_basket,
  'school' => Icons.school,
  'movie' => Icons.movie,
  'receipt' => Icons.receipt_long,
  'health' => Icons.favorite,
  'bag' => Icons.shopping_bag,
  'wallet' => Icons.account_balance_wallet,
  'work' => Icons.work,
  'star' => Icons.star,
  'gift' => Icons.card_giftcard,
  'savings' => Icons.savings,
  _ => Icons.category,
};

String typeLabel(TransactionType type) => switch (type) {
  TransactionType.income => 'Pemasukan',
  TransactionType.expense => 'Pengeluaran',
  TransactionType.transfer => 'Transfer',
};
