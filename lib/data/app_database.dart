
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract final class AppDatabase {
  static const int version = 2;
  static const String defaultCashAccountId = 'acc_cash';

  static Future<Database> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'sakurapi.db');
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _createSchema(db);
          await seedDefaults(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await createRecurringTable(db);
          }
        },
      ),
    );
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE accounts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('cash','bank','ewallet','savings')),
        initial_balance INTEGER NOT NULL DEFAULT 0 CHECK(initial_balance >= 0),
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('income','expense')),
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        UNIQUE(kind, name COLLATE NOCASE)
      )''');
    await db.execute('''
      CREATE TABLE savings_goals(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL CHECK(target_amount > 0),
        initial_amount INTEGER NOT NULL DEFAULT 0 CHECK(initial_amount >= 0),
        target_date TEXT,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        note TEXT,
        account_id TEXT NOT NULL REFERENCES accounts(id),
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('income','expense','transfer')),
        amount INTEGER NOT NULL CHECK(amount > 0),
        title TEXT NOT NULL DEFAULT '',
        category_id TEXT REFERENCES categories(id),
        account_id TEXT NOT NULL REFERENCES accounts(id),
        to_account_id TEXT REFERENCES accounts(id),
        goal_id TEXT REFERENCES savings_goals(id),
        goal_flow TEXT CHECK(goal_flow IN ('deposit','withdrawal')),
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(
          (type = 'transfer' AND to_account_id IS NOT NULL
             AND to_account_id <> account_id AND category_id IS NULL)
          OR
          (type <> 'transfer' AND to_account_id IS NULL
             AND category_id IS NOT NULL AND goal_id IS NULL)
        ),
        CHECK((goal_id IS NULL) = (goal_flow IS NULL))
      )''');
    await db.execute('''
      CREATE TABLE budgets(
        id TEXT PRIMARY KEY,
        category_id TEXT REFERENCES categories(id) ON DELETE CASCADE,
        limit_amount INTEGER NOT NULL CHECK(limit_amount > 0),
        created_at TEXT NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute(
      'CREATE INDEX idx_tx_category ON transactions(category_id)',
    );
    await db.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');
    await db.execute(
      'CREATE INDEX idx_tx_to_account ON transactions(to_account_id)',
    );
    await db.execute('CREATE INDEX idx_tx_goal ON transactions(goal_id)');

    await createRecurringTable(db);
  }

  /// Tabel aturan transaksi berulang (database versi 2).
  static Future<void> createRecurringTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE recurring_rules(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount INTEGER NOT NULL CHECK(amount > 0),
        title TEXT NOT NULL DEFAULT '',
        category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        frequency TEXT NOT NULL CHECK(frequency IN ('weekly','monthly','yearly')),
        start_date TEXT NOT NULL,
        next_date TEXT NOT NULL,
        end_date TEXT,
        note TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');
  }

  static const _defaultCategories = <(String, String, String, String, int)>[
    ('exp_food', 'Makanan & Minuman', 'expense', 'restaurant', 0xFFE76F72),
    ('exp_transport', 'Transportasi', 'expense', 'bus', 0xFF4F8FD8),
    ('exp_daily', 'Kebutuhan Sehari-hari', 'expense', 'basket', 0xFF7A9E4E),
    ('exp_education', 'Pendidikan', 'expense', 'school', 0xFF8E6CC9),
    ('exp_fun', 'Hiburan', 'expense', 'movie', 0xFFE6A23C),
    ('exp_bills', 'Tagihan', 'expense', 'receipt', 0xFF5B7C99),
    ('exp_health', 'Kesehatan', 'expense', 'health', 0xFF2EA8A0),
    ('exp_shopping', 'Belanja', 'expense', 'bag', 0xFFD97AA8),
    ('exp_other', 'Lainnya', 'expense', 'more', 0xFF8A9690),
    ('inc_allowance', 'Uang Saku', 'income', 'wallet', 0xFF18845B),
    ('inc_salary', 'Gaji / Penghasilan', 'income', 'work', 0xFF176B55),
    ('inc_bonus', 'Bonus', 'income', 'star', 0xFF3E9E7A),
    ('inc_gift', 'Hadiah', 'income', 'gift', 0xFF5FB28F),
    ('inc_other', 'Pemasukan Lainnya', 'income', 'more', 0xFF8A9690),
  ];

  static Future<void> seedDefaults(DatabaseExecutor db) async {
    final batch = db.batch();
    for (final (id, name, kind, icon, color) in _defaultCategories) {
      batch.insert('categories', {
        'id': id,
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
        'is_default': 1,
      });
    }
    batch.insert('accounts', {
      'id': defaultCashAccountId,
      'name': 'Dompet Tunai',
      'type': 'cash',
      'initial_balance': 0,
      'archived': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await batch.commit(noResult: true);
  }
}
