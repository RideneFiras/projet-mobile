import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/vehicule.dart';
import 'location_form_screen.dart';
import 'vehicule_form_screen.dart';

/// Liste des véhicules, en deux modes :
/// - [gestion] = true (administrateur) : ajout, modification, suppression de la flotte ;
/// - [gestion] = false (voyageur) : véhicules disponibles, « Réserver » pour un voyage.
class VehiculesTab extends StatefulWidget {
  final bool gestion;

  const VehiculesTab({super.key, this.gestion = false});

  @override
  State<VehiculesTab> createState() => _VehiculesTabState();
}

class _VehiculesTabState extends State<VehiculesTab> {
  final _repo = LocationRepository();
  late Future<List<Vehicule>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _repo.vehicules();
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _repo.vehicules();
    });
    await _futur;
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _modifier(Vehicule v) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VehiculeFormScreen(vehicule: v)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _reserver(Vehicule v) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LocationFormScreen(vehiculeId: v.id)),
    );
    if (ok == true && mounted) afficherMessage(context, 'Location enregistrée');
  }

  Future<void> _supprimer(Vehicule v) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ${v.nom} ?',
      message: 'Toutes les locations de ce véhicule seront supprimées aussi.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerVehicule(v.id!);
    if (!mounted) return;
    afficherMessage(context, 'Véhicule supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Vehicule>>(
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
        // Le voyageur ne voit que ce qu'il peut réserver.
        final tous = snap.data!;
        final liste = widget.gestion ? tous : tous.where((v) => v.disponible).toList();
        return RefreshIndicator(
          onRefresh: _recharger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              EnteteSection(
                titre: widget.gestion
                    ? 'Flotte (${tous.length})'
                    : 'Véhicules disponibles (${liste.length})',
                action: widget.gestion
                    ? TextButton.icon(
                        onPressed: _ajouter,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                (widget.gestion
                    ? EtatVideModule(
                        icone: Icons.directions_car_outlined,
                        titre: 'Aucun véhicule',
                        message: 'Ajoutez les véhicules proposés à la location.',
                        libelleAction: 'Ajouter un véhicule',
                        onAction: _ajouter,
                      )
                    : const EtatVideModule(
                        icone: Icons.directions_car_outlined,
                        titre: 'Aucun véhicule disponible',
                        message: 'Revenez plus tard : la flotte est mise à jour régulièrement.',
                      ))
              else
                GrilleAdaptative(
                  largeurMin: 320,
                  enfants: [for (final v in liste) _carte(v)],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _carte(Vehicule v) {
    final statut = v.disponible ? 'disponible' : 'indisponible';
    return CarteModule(
      accent: couleursStatut(statut).$2,
      onTap: widget.gestion ? () => _modifier(v) : () => _reserver(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.nom,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${Montants.affiche(v.prixParJour)} / jour',
                        style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Pastille(
                libelle: v.disponible ? 'Disponible' : 'Indisponible',
                valeur: statut,
              ),
              const Spacer(),
              if (widget.gestion)
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(v),
                )
              else
                TextButton.icon(
                  onPressed: () => _reserver(v),
                  icon: const Icon(Icons.event_available, size: 20),
                  label: const Text('Réserver',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.teal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
