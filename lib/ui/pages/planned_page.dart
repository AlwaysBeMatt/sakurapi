import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/empty_state.dart';

/// Halaman sementara untuk tab yang belum dibangun. Diganti di fase 3 sampai 6.
class PlannedPage extends StatelessWidget {
  const PlannedPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: EmptyState(
                icon: icon,
                title: 'Halaman $title sedang dibangun',
                message: description,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
