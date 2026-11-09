import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../forum_repository.dart';
import '../models/avis.dart';
import 'avis_form_screen.dart';

/// Onglet « Avis » : notes et commentaires sur les services (location, hébergement, transport).
class AvisTab extends StatefulWidget {
  const AvisTab({super.key});

  @override
  State<AvisTab> createState() => _AvisTabState();
}

class _Donnees {
  final List<Avis> avis;
  final int? userId;

  const _Donnees(this.avis, this.userId);
}

class _AvisTabState extends State<AvisTab> {
  final _repo = ForumRepository();
  late Future<_Donnees> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<_Donnees> _charger() async {
    final userId = await SessionService.instance.utilisateurId();
    final avis = await _repo.avis();
    return _Donnees(avis, userId);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _noter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AvisFormScreen()),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Avis publié');
      await _recharger();
    }
  }

  Future<void> _modifier(Avis a) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AvisFormScreen(avis: a)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _supprimer(Avis a, int userId) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer cet avis ?',
      message: 'Il ne sera plus visible par les autres voyageurs.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerAvis(a.id!, userId);
    if (!mounted) return;
    afficherMessage(context, 'Avis supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Donnees>(
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
        final donnees = snap.data!;
        final liste = donnees.avis;
        return RefreshIndicator(
          onRefresh: _recharger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              EnteteSection(
                titre: 'Avis (${liste.length})',
                action: TextButton.icon(
                  onPressed: _noter,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Noter'),
                ),
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                EtatVideModule(
                  icone: Icons.star_outline,
                  titre: 'Aucun avis',
                  message: 'Partagez votre expérience avec un service utilisé.',
                  libelleAction: 'Donner un avis',
                  onAction: _noter,
                )
              else
                ...[
                  for (final a in liste)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _carte(a, donnees.userId),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _carte(Avis a, int? userId) {
    final laMienne = userId != null && a.auteurId == userId;
    return CarteModule(
      accent: AppColors.orange,
      onTap: laMienne ? () => _modifier(a) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= a.note ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: AppColors.orange,
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(a.cible.libelle,
                    style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.libelleCible ?? 'Service supprimé',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (a.commentaire != null) ...[
            const SizedBox(height: 6),
            Text(a.commentaire!,
                style: const TextStyle(color: AppColors.navy, fontSize: 14, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.nomAuteur ?? 'Anonyme'} · ${dateCourte(a.creeLe)}',
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ),
              if (laMienne)
                IconButton(
                  tooltip: 'Supprimer',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(a, userId!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
