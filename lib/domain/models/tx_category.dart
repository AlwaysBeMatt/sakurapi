enum CategoryKind { income, expense }

/// Bernama TxCategory karena `Category` sudah dipakai oleh flutter/foundation.
class TxCategory {
  const TxCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.color,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final CategoryKind kind;

  /// Kunci ikon yang dipetakan ke IconData di UI.
  final String iconKey;
  final int color; // ARGB
  final bool isDefault;

  String? validate() {
    if (name.trim().isEmpty) return 'Nama kategori wajib diisi.';
    if (name.trim().length > 40) return 'Nama kategori maksimal 40 karakter.';
    return null;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'kind': kind.name,
    'icon': iconKey,
    'color': color,
    'is_default': isDefault ? 1 : 0,
  };

  factory TxCategory.fromMap(Map<String, Object?> m) => TxCategory(
    id: m['id']! as String,
    name: m['name']! as String,
    kind: CategoryKind.values.byName(m['kind']! as String),
    iconKey: m['icon']! as String,
    color: m['color']! as int,
    isDefault: m['is_default'] == 1,
  );
}
