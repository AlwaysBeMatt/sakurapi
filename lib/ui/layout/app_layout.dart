import 'package:flutter/widgets.dart';

abstract final class AppLayout {
  static const double contentMaxWidth = 1040;
  static const double twoColumnMinWidth = 680;

  /// Rail hanya dipakai jika tingginya cukup untuk lima tujuan
  /// (HP landscape tetap memakai bottom bar).
  static bool useRail(Size size) => size.width >= 600 && size.height >= 500;

  static bool extendedRail(Size size) => size.width >= 1200;
}
