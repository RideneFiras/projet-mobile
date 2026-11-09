import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
import 'contrat_screen.dart';
import 'location_form_screen.dart';

/// Onglet « Mes locations » : locations rattachées à vos voyages (CRUD).
class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});

  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> {
  final _repo = LocationRepository();
  late Future<List<LocationVehicule>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<List<LocationVehicule>> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    if (id == null) return const [];
    return _repo.locationsDe(id);
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
      MaterialPageRoute(builder: (_) => const LocationFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _modifier(LocationVehicule l) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LocationFormScreen(location: l)),
    );
    if (ok == true && mounted) await _recharger();
  }

  /// Annulation : la location reste dans l'historique, les dates sont libérées.
  Future<void> _annuler(LocationVehicule l) async {
    final ok = await confirmer(
      context,
      titre: 'Annuler cette location ?',
      message: 'La réservation du ${l.nomVehicule ?? 'véhicule'} sera annulée.',
    );
    if (!ok || !mounted) return;
    final id = await SessionService.instance.utilisateurId();
    final fait = id != null && await _repo.annulerLocation(l.id!, id);
    if (!mounted) return;
    afficherMessage(context, fait ? 'Location annulée' : 'Annulation impossible',
        erreur: !fait);
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LocationVehicule>>(
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
                titre: 'Réservations (${liste.length})',
                action: TextButton.icon(
                  onPressed: _ajouter,
                  icon: const Icon(Icons.add),
                  label: const Text('Réserver'),
                ),
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                EtatVideModule(
                  icone: Icons.event_busy_outlined,
                  titre: 'Aucune location',
                  message: 'Réservez un véhicule pour l\'un de vos voyages.',
                  libelleAction: 'Réserver un véhicule',
                  onAction: _ajouter,
                )
              else
                ...[
                  for (final l in liste)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _carte(l),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _carte(LocationVehicule l) {
    final (libelle, valeur) = l.affichageStatut;
    return CarteModule(
      accent: couleursStatut(valeur).$2,
      onTap: l.annulable ? () => _modifier(l) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(l.typeVehicule?.icone ?? Icons.directions_car,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.nomVehicule ?? 'Véhicule',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Pastille(libelle: libelle, valeur: valeur),
            ],
          ),
          const SizedBox(height: 6),
          Text('Voyage : ${l.titreVoyage ?? '—'}',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${periode(l.dateDebut, l.dateFin)}  ·  ${l.jours} j',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          if (l.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Options : ${l.options.map((o) => o.libelle).join(', ')}',
                style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          ],
          if (l.penalite > 0) ...[
            const SizedBox(height: 4),
            Text('Pénalité de retard : ${Montants.affiche(l.penalite)}',
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(Montants.affiche(l.totalDu),
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              if (l.caution > 0)
                Text('  + caution ${Montants.affiche(l.caution)}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12)),
              const Spacer(),
              if (!l.annulee)
                IconButton(
                  tooltip: l.contratSigneLe == null ? 'Signer le contrat' : 'Contrat signé',
                  icon: Icon(
                      l.contratSigneLe == null ? Icons.draw_outlined : Icons.verified_outlined,
                      color: AppColors.teal),
                  onPressed: () async {
                    await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => ContratScreen(locationId: l.id!)));
                    if (mounted) await _recharger();
                  },
                ),
              if (l.annulable)
                IconButton(
                  tooltip: 'Annuler la location',
                  icon: const Icon(Icons.event_busy_outlined, color: AppColors.danger),
                  onPressed: () => _annuler(l),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
