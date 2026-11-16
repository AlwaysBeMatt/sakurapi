/// Kesalahan input yang pesannya aman ditampilkan ke pengguna.
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
