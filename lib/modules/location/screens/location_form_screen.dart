import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../voyage/models/voyage.dart';
import '../../voyage/voyage_repository.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
import '../models/vehicule.dart';

/// Réservation d'un véhicule pour un de vos voyages. Le prix est calculé
/// automatiquement et les dates qui se chevauchent sont refusées.
class LocationFormScreen extends StatefulWidget {
  final LocationVehicule? location;

  /// Véhicule préchoisi (ouverture depuis l'onglet Véhicules).
  final int? vehiculeId;

  const LocationFormScreen({super.key, this.location, this.vehiculeId});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _Donnees {
  final List<Vehicule> vehicules;
  final List<Voyage> voyages;

  const _Donnees(this.vehicules, this.voyages);
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _repo = LocationRepository();
  late Future<_Donnees> _donnees;
  int? _vehiculeId;
  int? _voyageId;
  DateTime? _debut;
  DateTime? _fin;
  String? _erreurDates;
  String? _erreurChoix;
  String? _erreurServeur;
  bool _enregistrement = false;

  bool get _modeEdition => widget.location != null;

  @override
  void initState() {
    super.initState();
    final l = widget.location;
    _vehiculeId = l?.vehiculeId ?? widget.vehiculeId;
    _voyageId = l?.voyageId;
    _debut = l?.dateDebut;
    _fin = l?.dateFin;
    _donnees = _charger();
  }

  Future<_Donnees> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    final vehicules = await _repo.vehicules();
    final voyages =
        id == null ? <Voyage>[] : await VoyageRepository().voyagesDe(id);
    return _Donnees(vehicules, voyages);
  }

  String? _verifierDates() {
    if (_debut == null || _fin == null) return 'Choisissez les deux dates';
    return LocationVehicule.verifierPeriode(_debut!, _fin!);
  }

  Vehicule? _vehiculeChoisi(List<Vehicule> liste) {
    for (final v in liste) {
      if (v.id == _vehiculeId) return v;
    }
    return null;
  }

  Future<void> _enregistrer() async {
    final dates = _verifierDates();
    final choix = (_vehiculeId == null || _voyageId == null)
        ? 'Choisissez un véhicule et un voyage'
        : null;
    setState(() {
      _erreurDates = dates;
      _erreurChoix = choix;
      _erreurServeur = null;
    });
    if (dates != null || choix != null) return;

    setState(() => _enregistrement = true);
    final erreur = await _repo.enregistrer(LocationVehicule(
      id: widget.location?.id,
      dateDebut: _debut!,
      dateFin: _fin!,
      voyageId: _voyageId!,
      vehiculeId: _vehiculeId!,
    ));
    if (!mounted) return;
    if (erreur != null) {
      setState(() {
        _enregistrement = false;
        _erreurServeur = erreur;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier la location' : 'Nouvelle location',
      corps: FutureBuilder<_Donnees>(
        future: _donnees,
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
          return _formulaire(snap.data!);
        },
      ),
    );
  }

  Widget _formulaire(_Donnees donnees) {
    // Une valeur absente de la liste ferait échouer le DropdownButton : on la retire.
    final vehiculeValide =
        donnees.vehicules.any((v) => v.id == _vehiculeId) ? _vehiculeId : null;
    final voyageValide =
        donnees.voyages.any((v) => v.id == _voyageId) ? _voyageId : null;
    final pretAEnregistrer =
        donnees.vehicules.isNotEmpty && donnees.voyages.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (donnees.voyages.isEmpty)
          _bandeau('Créez d\'abord un voyage : chaque location est rattachée à l\'un de vos voyages.'),
        if (donnees.vehicules.isEmpty)
          _bandeau('Ajoutez d\'abord un véhicule dans l\'onglet Véhicules.'),
        ChampChoix<int>(
          label: 'Véhicule',
          icone: Icons.directions_car_outlined,
          valeur: vehiculeValide,
          erreur: vehiculeValide == null ? _erreurChoix : null,
          items: [
            for (final v in donnees.vehicules)
              DropdownMenuItem<int>(
                value: v.id!,
                child: Text('${v.nom} · ${Montants.affiche(v.prixParJour)} / jour'),
              ),
          ],
          onChange: (id) => setState(() => _vehiculeId = id),
        ),
        const SizedBox(height: 14),
        ChampChoix<int>(
          label: 'Voyage concerné',
          icone: Icons.luggage_outlined,
          valeur: voyageValide,
          erreur: voyageValide == null ? _erreurChoix : null,
          items: [
            for (final v in donnees.voyages)
              DropdownMenuItem<int>(
                value: v.id!,
                child: Text(v.titre, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChange: (id) => setState(() => _voyageId = id),
        ),
        const SizedBox(height: 14),
        ChampDate(
          label: 'Prise en charge',
          valeur: _debut,
          erreur: _erreurDates,
          onChoisie: (date) => setState(() {
            _debut = date;
            _erreurDates = null;
          }),
        ),
        const SizedBox(height: 14),
        ChampDate(
          label: 'Retour',
          valeur: _fin,
          erreur: _erreurDates,
          premiereDate: _debut,
          onChoisie: (date) => setState(() {
            _fin = date;
            _erreurDates = null;
          }),
        ),
        const SizedBox(height: 16),
        _apercu(_vehiculeChoisi(donnees.vehicules)),
        const SizedBox(height: 24),
        if (_erreurServeur != null) _bandeauErreur(_erreurServeur!),
        BoutonPrincipal(
          libelle: _modeEdition ? 'Enregistrer les modifications' : 'Confirmer la location',
          icone: Icons.check,
          onPressed: (_enregistrement || !pretAEnregistrer) ? null : _enregistrer,
        ),
        const SizedBox(height: 12),
        BoutonSecondaire(
          libelle: 'Annuler',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Estimation affichée dès que véhicule et dates sont valides.
  Widget _apercu(Vehicule? v) {
    if (v == null || _debut == null || _fin == null || _verifierDates() != null) {
      return const SizedBox.shrink();
    }
    final jours = nombreDeJours(_debut!, _fin!) + 1;
    final total = v.prixParJour * jours;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ESTIMATION',
              style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '$jours jour${jours > 1 ? 's' : ''} × ${Montants.affiche(v.prixParJour)}',
            style: const TextStyle(
                color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(Montants.affiche(total),
              style: const TextStyle(
                  color: AppColors.teal, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _bandeau(String texte) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
        child: Text(texte,
            style: const TextStyle(
                color: AppColors.orangeText, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _bandeauErreur(String texte) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFBE3E0), borderRadius: BorderRadius.circular(12)),
        child: Text(texte,
            style: const TextStyle(
                color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}
