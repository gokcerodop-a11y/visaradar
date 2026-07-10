import 'package:flutter/material.dart';

class SosFab extends StatelessWidget {
  final VoidCallback onPressed;
  const SosFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'sos_fab',
      onPressed: onPressed,
      backgroundColor: const Color(0xFFEF4444),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.emergency, size: 22),
    );
  }
}
