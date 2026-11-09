import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../forum_repository.dart';
import '../models/sujet_forum.dart';
import 'sujet_detail_screen.dart';
import 'sujet_form_screen.dart';

/// Onglet « Discussions » : liste des sujets, création et ouverture d'un fil.
class SujetsTab extends StatefulWidget {
  const SujetsTab({super.key});

  @override
  State<SujetsTab> createState() => _SujetsTabState();
}

class _SujetsTabState extends State<SujetsTab> {
  final _repo = ForumRepository();
  late Future<List<SujetForum>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _repo.sujets();
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _repo.sujets();
    });
    await _futur;
  }

  Future<void> _nouveau() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SujetFormScreen()),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Discussion publiée');
      await _recharger();
    }
  }

  Future<void> _ouvrir(SujetForum s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SujetDetailScreen(sujetId: s.id!)),
    );
    if (mounted) await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SujetForum>>(
      future: _futur,
      builder: (context, snap) {
        if (snap.hasError) {
          return EtatVideModule(
            icone: Icons.error_outline,
            titre: 'Chargement impossible',
            message: '${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final liste = snap.data!;
        return RefreshIndicator(
          onRefresh: _recharger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              EnteteSection(
                titre: 'Discussions (${liste.length})',
                action: TextButton.icon(
                  onPressed: _nouveau,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Écrire'),
                ),
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                EtatVideModule(
                  icone: Icons.forum_outlined,
                  titre: 'Aucune discussion',
                  message: 'Posez une question ou partagez un bon plan de voyage.',
                  libelleAction: 'Démarrer une discussion',
                  onAction: _nouveau,
                )
              else
                ...[
                  for (final s in liste)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _carte(s),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _carte(SujetForum s) {
    return CarteModule(
      onTap: () => _ouvrir(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.titre,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(s.contenu,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.tealLight,
                child: Text(
                  (s.nomAuteur ?? '?').isEmpty ? '?' : s.nomAuteur!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${s.nomAuteur ?? 'Anonyme'} · ${dateCourte(s.creeLe)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ),
              const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.grey),
              const SizedBox(width: 4),
              Text('${s.nbReponses}',
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
