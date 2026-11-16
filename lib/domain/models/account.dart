import '../../core/money.dart';

enum AccountType {
  cash('Dompet tunai'),
  bank('Rekening bank'),
  ewallet('E-wallet'),
  savings('Rekening tabungan');

  const AccountType(this.label);
  final String label;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.initialBalance = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final AccountType type;
  final int initialBalance;
  final bool archived;
  final DateTime createdAt;

  String? validate() {
    if (name.trim().isEmpty) return 'Nama akun wajib diisi.';
    if (name.trim().length > 40) return 'Nama akun maksimal 40 karakter.';
    if (initialBalance < 0) return 'Saldo awal tidak boleh negatif.';
    if (initialBalance > Money.maxAmount) return 'Saldo awal terlalu besar.';
    return null;
  }

  Account copyWith({
    String? name,
    AccountType? type,
    int? initialBalance,
    bool? archived,
  }) => Account(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    initialBalance: initialBalance ?? this.initialBalance,
    archived: archived ?? this.archived,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'type': type.name,
    'initial_balance': initialBalance,
    'archived': archived ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory Account.fromMap(Map<String, Object?> m) => Account(
    id: m['id']! as String,
    name: m['name']! as String,
    type: AccountType.values.byName(m['type']! as String),
    initialBalance: m['initial_balance']! as int,
    archived: m['archived'] == 1,
    createdAt: DateTime.parse(m['created_at']! as String),
  );
}
