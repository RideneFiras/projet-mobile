import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/galerie_photos.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/filtres_vehicule.dart';
import '../models/vehicule.dart';
import 'assistant_location_screen.dart';
import 'carte_vehicules_screen.dart';
import 'filtres_vehicule_sheet.dart';
import 'vehicule_detail_screen.dart';
import 'vehicule_form_screen.dart';

/// Liste des véhicules (voitures, motos, bicyclettes), en deux modes :
/// - [gestion] = true (administrateur) : toute la flotte, ajout et suppression,
///   alertes d'entretien ;
/// - [gestion] = false (voyageur) : véhicules réservables uniquement.
/// Recherche, puces de type, filtres avancés, tri, carte et assistant IA.
class VehiculesTab extends StatefulWidget {
  final bool gestion;

  const VehiculesTab({super.key, this.gestion = false});

  @override
  State<VehiculesTab> createState() => _VehiculesTabState();
}

class _VehiculesTabState extends State<VehiculesTab> {
  final _repo = LocationRepository();
  final _recherche = TextEditingController();
  FiltresVehicule _filtres = const FiltresVehicule();
  late Future<List<Vehicule>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<List<Vehicule>> _charger() => _repo.vehicules(
        reservablesSeulement: !widget.gestion,
        filtres: _filtres.copyWith(recherche: _recherche.text),
      );

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _ouvrirFiltres() async {
    final f = await ouvrirFiltresVehicule(context, _filtres);
    if (f == null || !mounted) return;
    _filtres = f;
    await _recharger();
  }

  Future<void> _ouvrirAssistant() async {
    final f = await Navigator.push<FiltresVehicule>(
      context,
      MaterialPageRoute(builder: (_) => const AssistantLocationScreen()),
    );
    if (f == null || !mounted) return;
    _filtres = f;
    _recherche.clear();
    await _recharger();
  }

  Future<void> _ouvrirCarte() async {
    final vehicules = await _futur;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CarteVehiculesScreen(vehicules: vehicules, gestion: widget.gestion),
      ),
    );
    if (mounted) await _recharger();
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _ouvrir(Vehicule v) async {
    final change = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VehiculeDetailScreen(vehiculeId: v.id!, gestion: widget.gestion),
      ),
    );
    if (change == true && mounted) await _recharger();
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
    final nbFiltres = _filtres.nombreActifs;
    return RefreshIndicator(
      onRefresh: _recharger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          TextField(
            controller: _recherche,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _recharger(),
            decoration: decorationUi('Marque, modèle, immatriculation, ville…',
                    icone: Icons.search)
                .copyWith(
              suffixIcon: IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _recherche.clear();
                  _recharger();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _filtresType(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _ouvrirFiltres,
                icon: Badge(
                  isLabelVisible: nbFiltres > 0,
                  label: Text('$nbFiltres'),
                  child: const Icon(Icons.tune),
                ),
                label: Text('Filtres · ${_filtres.tri.libelle}'),
              ),
              OutlinedButton.icon(
                onPressed: _ouvrirCarte,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Carte'),
              ),
              if (!widget.gestion)
                FilledButton.tonalIcon(
                  onPressed: _ouvrirAssistant,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Assistant IA'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Vehicule>>(
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
              return _liste(snap.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _filtresType() {
    Widget puce(TypeVehicule? t, String libelle, IconData icone) {
      final actif = _filtres.type == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icone, size: 18, color: actif ? AppColors.white : AppColors.teal),
          label: Text(libelle),
          selected: actif,
          showCheckmark: false,
          selectedColor: AppColors.teal,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.border),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: actif ? AppColors.white : AppColors.navy,
          ),
          onSelected: (_) {
            _filtres = t == null
                ? _filtres.copyWith(effacerType: true)
                : _filtres.copyWith(type: t);
            _recharger();
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          puce(null, 'Tous', Icons.apps),
          for (final t in TypeVehicule.values) puce(t, t.libelle, t.icone),
        ],
      ),
    );
  }

  Widget _liste(List<Vehicule> liste) {
    final revisions = liste.where((v) => v.revisionDue).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnteteSection(
          titre: widget.gestion
              ? 'Flotte (${liste.length})'
              : 'Véhicules disponibles (${liste.length})',
          action: widget.gestion
              ? TextButton.icon(
                  onPressed: _ajouter,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                )
              : null,
        ),
        if (widget.gestion && revisions > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: AppColors.orangeText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$revisions véhicule${revisions > 1 ? 's ont' : ' a'} besoin d\'une révision.',
                    style: const TextStyle(
                        color: AppColors.orangeText, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (liste.isEmpty)
          (widget.gestion
              ? EtatVideModule(
                  icone: Icons.directions_car_outlined,
                  titre: 'Aucun véhicule',
                  message: 'Ajoutez les voitures, motos et bicyclettes proposées à la location.',
                  libelleAction: 'Ajouter un véhicule',
                  onAction: _ajouter,
                )
              : const EtatVideModule(
                  icone: Icons.directions_car_outlined,
                  titre: 'Aucun véhicule disponible',
                  message: 'Changez de filtres ou demandez à l\'assistant IA.',
                ))
        else
          GrilleAdaptative(
            largeurMin: 320,
            enfants: [for (final v in liste) _carte(v)],
          ),
      ],
    );
  }

  /// Statut affiché : « Loué aujourd'hui » prime sur « Disponible ».
  (String, String) _statut(Vehicule v) => v.disponible && v.enLocation
      ? ('Loué aujourd\'hui', 'loue')
      : (v.statut.libelle, v.statut.valeur);

  Widget _carte(Vehicule v) {
    final (libelle, valeur) = _statut(v);
    final distance = (_filtres.aPositionRef && v.aPosition)
        ? distanceKm(_filtres.latitudeRef!, _filtres.longitudeRef!, v.latitude!, v.longitude!)
        : null;
    return CarteModule(
      accent: couleursStatut(valeur).$2,
      onTap: () => _ouvrir(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PhotoModule(
                source: v.photoPrincipale,
                iconeParDefaut: v.type.icone,
                hauteur: 140,
                largeur: double.infinity,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Wrap(
                  spacing: 6,
                  children: [
                    _badge(v.type.icone, v.type.libelle),
                    if (v.estElectrique) _badge(Icons.bolt, 'Électrique'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(v.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (v.nbAvis > 0) ...[
                const Icon(Icons.star_rounded, color: AppColors.orange, size: 18),
                Text(v.noteMoyenne.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(v.resumeTechnique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          if (v.adresse != null || distance != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      [
                        if (distance != null) distanceLisible(distance),
                        if (v.adresse != null) v.adresse!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
              ],
            ),
          ],
          if (widget.gestion && (v.revisionDue || v.revisionProche)) ...[
            const SizedBox(height: 6),
            Pastille(
              libelle: v.revisionDue ? 'Révision due' : 'Révision bientôt',
              valeur: v.revisionDue ? 'hors_service' : 'maintenance',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Pastille(libelle: libelle, valeur: valeur),
              if (v.nbLocations > 0) ...[
                const SizedBox(width: 6),
                Text('${v.nbLocations} loc.',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12)),
              ],
              const Spacer(),
              Text('${Montants.affiche(v.prixParJour)} / jour',
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 15, fontWeight: FontWeight.w800)),
              if (widget.gestion)
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(v),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icone, String texte) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: AppColors.teal),
            const SizedBox(width: 4),
            Text(texte,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ],
        ),
      );
}
