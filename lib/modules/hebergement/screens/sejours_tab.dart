import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_repository.dart';
import '../models/reservation_hebergement.dart';
import 'sejour_form_screen.dart';

/// Onglet « Mes séjours » : séjours rattachés à vos voyages (CRUD).
class SejoursTab extends StatefulWidget {
  const SejoursTab({super.key});

  @override
  State<SejoursTab> createState() => _SejoursTabState();
}

class _SejoursTabState extends State<SejoursTab> {
  final _repo = HebergementRepository();
  late Future<List<ReservationHebergement>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<List<ReservationHebergement>> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    if (id == null) return const [];
    return _repo.sejoursDe(id);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SejourFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _modifier(ReservationHebergement s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SejourFormScreen(sejour: s)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _supprimer(ReservationHebergement s) async {
    final ok = await confirmer(
      context,
      titre: 'Annuler ce séjour ?',
      message: 'Le séjour à ${s.nomHebergement ?? 'l\'établissement'} sera supprimé.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerSejour(s.id!);
    if (!mounted) return;
    afficherMessage(context, 'Séjour supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReservationHebergement>>(
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
                titre: 'Séjours (${liste.length})',
                action: TextButton.icon(
                  onPressed: _ajouter,
                  icon: const Icon(Icons.add),
                  label: const Text('Réserver'),
                ),
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                EtatVideModule(
                  icone: Icons.bed_outlined,
                  titre: 'Aucun séjour réservé',
                  message: 'Réservez un hébergement pour l\'un de vos voyages.',
                  libelleAction: 'Réserver un séjour',
                  onAction: _ajouter,
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

  Widget _carte(ReservationHebergement s) {
    return CarteModule(
      accent: AppColors.orange,
      onTap: () => _modifier(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bed_outlined, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.nomHebergement ?? 'Établissement',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Voyage : ${s.titreVoyage ?? '—'}',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${periode(s.dateArrivee, s.dateDepart)}  ·  ${s.nuits} nuit${s.nuits > 1 ? 's' : ''}'
            '  ·  ${s.nbPersonnes} pers.',
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(Montants.affiche(s.prixTotal),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Annuler le séjour',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => _supprimer(s),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
