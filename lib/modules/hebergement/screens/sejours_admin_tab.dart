import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_repository.dart';
import '../models/reservation_hebergement.dart';

/// Onglet administrateur « Séjours » : réception (check-in avec le code à 6 chiffres
/// du client, check-out) et historique de toutes les réservations.
class SejoursAdminTab extends StatefulWidget {
  const SejoursAdminTab({super.key});

  @override
  State<SejoursAdminTab> createState() => _SejoursAdminTabState();
}

class _SejoursAdminTabState extends State<SejoursAdminTab> {
  final _repo = HebergementRepository();
  bool _aTraiter = true;
  late Future<List<({ReservationHebergement sejour, String client})>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _repo.tousLesSejours(aTraiter: _aTraiter);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _repo.tousLesSejours(aTraiter: _aTraiter);
    });
    await _futur;
  }

  Future<void> _checkIn(ReservationHebergement s, String client) async {
    final code = TextEditingController();
    final valide = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Arrivée de $client'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: decorationUi('Code d\'arrivée (6 chiffres)', icone: Icons.key_outlined),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    final saisi = code.text;
    code.dispose();
    if (valide != true || !mounted) return;
    final erreur = await _repo.validerCheckIn(s.id!, saisi);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Check-in validé : bienvenue !', erreur: erreur != null);
    if (erreur == null) await _recharger();
  }

  Future<void> _checkOut(ReservationHebergement s, String client) async {
    final ok = await confirmer(context,
        titre: 'Départ de $client ?', message: 'La chambre sera libérée immédiatement.');
    if (!ok || !mounted) return;
    final erreur = await _repo.checkOut(s.id!);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Check-out enregistré', erreur: erreur != null);
    if (erreur == null) await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _recharger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Réception du jour'), icon: Icon(Icons.login)),
              ButtonSegment(value: false, label: Text('Tous les séjours'), icon: Icon(Icons.list)),
            ],
            selected: {_aTraiter},
            onSelectionChanged: (s) {
              _aTraiter = s.first;
              _recharger();
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<({ReservationHebergement sejour, String client})>>(
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
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final liste = snap.data!;
              if (liste.isEmpty) {
                return EtatVideModule(
                  icone: Icons.hotel_class_outlined,
                  titre: _aTraiter ? 'Personne à accueillir' : 'Aucun séjour',
                  message: _aTraiter
                      ? 'Aucune arrivée prévue aujourd\'hui et aucun client présent.'
                      : 'Les réservations des voyageurs apparaîtront ici.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in liste) ...[
                    _carte(e.sejour, e.client),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _carte(ReservationHebergement s, String client) {
    final statut = s.statutEffectif;
    return CarteModule(
      accent: couleursStatut(statut.valeur).$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(s.typeHebergement?.icone ?? Icons.bed_outlined,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.nomHebergement ?? 'Établissement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Pastille(libelle: statut.libelle, valeur: statut.valeur),
            ],
          ),
          const SizedBox(height: 6),
          Text('$client · ${s.nbPersonnes} pers. · ${s.nbChambres} × ${s.typeChambre.libelle}',
              style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          Text('${periode(s.dateArrivee, s.dateDepart)} · ${s.nuits} nuit${s.nuits > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          if (s.demandes != null)
            Text('Demande : ${s.demandes}',
                style: const TextStyle(color: AppColors.navy, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(Montants.affiche(s.prixTotal),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (s.peutCheckIn)
                FilledButton.tonalIcon(
                  onPressed: () => _checkIn(s, client),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Check-in'),
                ),
              if (s.peutCheckOut)
                FilledButton.tonalIcon(
                  onPressed: () => _checkOut(s, client),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Check-out'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
