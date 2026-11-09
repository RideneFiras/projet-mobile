import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Écran d'attente pour un module pas encore développé.
class ComingSoonScreen extends StatelessWidget {
  final String titre;
  final String module;
  final String responsable;
  final IconData icone;

  const ComingSoonScreen({
    super.key,
    required this.titre,
    required this.module,
    required this.responsable,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                    color: AppColors.tealLight, shape: BoxShape.circle),
                child: Icon(icone, size: 40, color: AppColors.teal),
              ),
              const SizedBox(height: 24),
              const Text('Module à venir',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Module $module',
                  style: const TextStyle(color: AppColors.grey, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Responsable : $responsable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.grey, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
