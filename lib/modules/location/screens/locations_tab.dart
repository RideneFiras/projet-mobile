import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
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

  Future<void> _supprimer(LocationVehicule l) async {
    final ok = await confirmer(
      context,
      titre: 'Annuler cette location ?',
      message: 'La réservation du ${l.nomVehicule ?? 'véhicule'} sera supprimée.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerLocation(l.id!);
    if (!mounted) return;
    afficherMessage(context, 'Location supprimée');
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
    return CarteModule(
      accent: AppColors.orange,
      onTap: () => _modifier(l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.nomVehicule ?? 'Véhicule',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Voyage : ${l.titreVoyage ?? '—'}',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${periode(l.dateDebut, l.dateFin)}  ·  ${l.jours} j',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(Montants.affiche(l.prixTotal),
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Annuler la location',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => _supprimer(l),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
