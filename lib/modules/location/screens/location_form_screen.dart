import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../user/user_repository.dart';
import '../../voyage/models/voyage.dart';
import '../../voyage/voyage_repository.dart';
import '../location_email_service.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
import '../models/option_location.dart';
import '../models/vehicule.dart';

/// Réservation d'un véhicule pour un de vos voyages :
/// dates (jours déjà pris désactivés), lieux de prise en charge et de retour,
/// options payantes, notes. Le prix est recalculé par le repository ;
/// un e-mail de confirmation part ensuite sans bloquer l'écran.
class LocationFormScreen extends StatefulWidget {
  final LocationVehicule? location;

  /// Véhicule préchoisi (ouverture depuis l'onglet Véhicules ou la fiche).
  final int? vehiculeId;

  /// Dates préchoisies (réservation rapide depuis le calendrier de la fiche).
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const LocationFormScreen(
      {super.key, this.location, this.vehiculeId, this.dateDebut, this.dateFin});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _Donnees {
  final List<Vehicule> vehicules;
  final List<Voyage> voyages;
  final int? utilisateurId;
  final String? email;

  const _Donnees(this.vehicules, this.voyages, this.utilisateurId, this.email);
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _repo = LocationRepository();
  final _lieuPrise = TextEditingController();
  final _lieuRetour = TextEditingController();
  final _notes = TextEditingController();
  final _permis = TextEditingController();
  String? _erreurPermis;
  late Future<_Donnees> _donnees;
  int? _vehiculeId;
  int? _voyageId;
  DateTime? _debut;
  DateTime? _fin;
  final Set<OptionLocation> _options = {};
  bool _memeLieu = true;

  /// Périodes déjà réservées du véhicule choisi (hors location modifiée).
  List<(DateTime, DateTime)> _periodes = const [];
  bool _chargementPeriodes = false;

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
    _debut = l?.dateDebut ?? widget.dateDebut;
    _fin = l?.dateFin ?? widget.dateFin;
    _permis.text = l?.numeroPermis ?? '';
    if (l != null) {
      _options.addAll(l.options);
      _lieuPrise.text = l.lieuPrise ?? '';
      _notes.text = l.notes ?? '';
      _memeLieu = l.lieuRetour == null || l.lieuRetour == l.lieuPrise;
      if (!_memeLieu) _lieuRetour.text = l.lieuRetour!;
    }
    _donnees = _charger();
  }

  @override
  void dispose() {
    _lieuPrise.dispose();
    _lieuRetour.dispose();
    _notes.dispose();
    _permis.dispose();
    super.dispose();
  }

  Future<_Donnees> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    final utilisateur = await UserRepository().utilisateurConnecte();
    // Véhicules réservables + celui de la location modifiée (même s'il ne l'est plus).
    final vehicules = (await _repo.vehicules())
        .where((v) => v.disponible || v.id == _vehiculeId)
        .toList();
    final voyages =
        id == null ? <Voyage>[] : await VoyageRepository().voyagesDe(id);
    final choisi = _vehiculeChoisi(vehicules);
    if (choisi != null) {
      if (_lieuPrise.text.isEmpty) _lieuPrise.text = choisi.adresse ?? '';
      _periodes = await _repo.periodesReservees(choisi.id!, exclureId: widget.location?.id);
    }
    return _Donnees(vehicules, voyages, id, utilisateur?.email);
  }

  Vehicule? _vehiculeChoisi(List<Vehicule> liste) {
    for (final v in liste) {
      if (v.id == _vehiculeId) return v;
    }
    return null;
  }

  /// Changement de véhicule : options filtrées selon le type, lieu pré-rempli,
  /// dates effacées si elles tombent sur des jours désormais indisponibles.
  Future<void> _choisirVehicule(int? id, List<Vehicule> liste) async {
    final ancien = _vehiculeChoisi(liste);
    setState(() {
      _vehiculeId = id;
      _chargementPeriodes = id != null;
      _periodes = const [];
    });
    final v = _vehiculeChoisi(liste);
    if (v == null) return;
    _options.removeWhere((o) => !o.autorisePour(v.type));
    if (_lieuPrise.text.isEmpty || _lieuPrise.text == (ancien?.adresse ?? '')) {
      _lieuPrise.text = v.adresse ?? '';
    }
    final periodes = await _repo.periodesReservees(v.id!, exclureId: widget.location?.id);
    if (!mounted || _vehiculeId != v.id) return;
    setState(() {
      _periodes = periodes;
      _chargementPeriodes = false;
      if (_debut != null && _fin != null && !_plageLibre(_debut!, _fin!)) {
        _debut = null;
        _fin = null;
        _erreurDates = 'Ces dates ne sont plus libres pour ce véhicule';
      }
    });
  }

  // --- Calendrier des disponibilités ---------------------------------

  bool _jourPris(DateTime jour) {
    final j = dateJour(jour);
    return _periodes.any(
        (p) => !j.isBefore(dateJour(p.$1)) && !j.isAfter(dateJour(p.$2)));
  }

  /// Aucun jour réservé entre [debut] et [fin] inclus.
  bool _plageLibre(DateTime debut, DateTime fin) {
    final d = dateJour(debut);
    final f = dateJour(fin);
    return !_periodes.any(
        (p) => !dateJour(p.$1).isAfter(f) && !dateJour(p.$2).isBefore(d));
  }

  /// Jour sélectionnable : libre et, si le début est choisi, sans jour pris entre les deux.
  bool _selectionnable(DateTime jour, DateTime? debut, DateTime? fin) {
    if (_jourPris(jour)) return false;
    if (debut != null && fin == null && jour.isAfter(debut)) {
      return _plageLibre(debut, jour);
    }
    return true;
  }

  Future<void> _choisirDates() async {
    if (_vehiculeId == null) {
      setState(() => _erreurDates = 'Choisissez d\'abord un véhicule');
      return;
    }
    final aujourdhui = dateJour(DateTime.now());
    final premiere = (_debut != null && _debut!.isBefore(aujourdhui))
        ? dateJour(_debut!)
        : aujourdhui;
    final derniere = DateTime(aujourdhui.year + 2, 12, 31);
    final initiale = (_debut != null && _fin != null && !_fin!.isAfter(derniere))
        ? DateTimeRange(start: dateJour(_debut!), end: dateJour(_fin!))
        : null;
    final plage = await showDateRangePicker(
      context: context,
      firstDate: premiere,
      lastDate: derniere,
      initialDateRange: initiale,
      helpText: 'Dates de location',
      saveText: 'Valider',
      selectableDayPredicate: _selectionnable,
    );
    if (plage == null || !mounted) return;
    setState(() {
      if (!_plageLibre(plage.start, plage.end)) {
        _erreurDates = 'La période contient des jours déjà réservés';
        return;
      }
      _debut = plage.start;
      _fin = plage.end;
      _erreurDates = null;
    });
  }

  // --- Enregistrement ----------------------------------------------

  String? _verifierDates() {
    if (_debut == null || _fin == null) return 'Choisissez les dates de location';
    return LocationVehicule.verifierPeriode(_debut!, _fin!);
  }

  /// Options dans l'ordre de l'énumération (affichage et stockage stables).
  List<OptionLocation> get _optionsTriees =>
      [for (final o in OptionLocation.values) if (_options.contains(o)) o];

  Future<void> _enregistrer(_Donnees donnees) async {
    final dates = _verifierDates();
    final choix = (_vehiculeId == null || _voyageId == null)
        ? 'Choisissez un véhicule et un voyage'
        : null;
    final lieuRetourManquant = !_memeLieu && _lieuRetour.text.trim().isEmpty;
    final vehiculeChoisi = _vehiculeChoisi(donnees.vehicules);
    // Permis obligatoire pour une voiture ou une moto.
    final permis = LocationVehicule.verifierPermis(_permis.text,
        obligatoire: vehiculeChoisi?.type.motorise ?? false);
    setState(() {
      _erreurDates = dates;
      _erreurChoix = choix;
      _erreurPermis = permis;
      _erreurServeur = lieuRetourManquant ? 'Indiquez le lieu de retour' : null;
    });
    if (dates != null || choix != null || lieuRetourManquant || permis != null) return;

    final lieuPrise = _lieuPrise.text.trim();
    final location = LocationVehicule(
      id: widget.location?.id,
      dateDebut: _debut!,
      dateFin: _fin!,
      voyageId: _voyageId!,
      vehiculeId: _vehiculeId!,
      statut: widget.location?.statut ?? StatutLocation.confirmee,
      lieuPrise: lieuPrise,
      lieuRetour: _memeLieu ? lieuPrise : _lieuRetour.text,
      notes: _notes.text,
      options: _optionsTriees,
      numeroPermis: _permis.text,
      creeLe: widget.location?.creeLe,
    );

    setState(() => _enregistrement = true);
    final erreur = await _repo.enregistrer(location, utilisateurId: donnees.utilisateurId);
    if (!mounted) return;
    if (erreur != null) {
      setState(() {
        _enregistrement = false;
        _erreurServeur = erreur;
      });
      return;
    }

    // E-mail en arrière-plan : l'écran se ferme tout de suite ; le message
    // n'apparaît que si l'envoi réussit (rien si non configuré ou hors connexion).
    final vehicule = _vehiculeChoisi(donnees.vehicules);
    final email = donnees.email;
    if (vehicule != null && email != null) {
      final messager = ScaffoldMessenger.of(context);
      final confirmee = LocationVehicule(
        vehiculeId: location.vehiculeId,
        voyageId: location.voyageId,
        dateDebut: location.dateDebut,
        dateFin: location.dateFin,
        lieuPrise: location.lieuPrise,
        options: location.options,
        caution: vehicule.caution,
        prixTotal: LocationVehicule.calculerPrixDynamique(
          regles: vehicule.reglesTarif,
          prixParJour: vehicule.prixParJour,
          options: location.options,
          debut: location.dateDebut,
          fin: location.dateFin,
        ).total,
      );
      unawaited(LocationEmailService()
          .envoyerConfirmation(
            email: email,
            location: confirmee,
            nomVehicule: vehicule.nom,
            typeVehicule: vehicule.type,
          )
          .then((envoye) {
        if (envoye) {
          messager.showSnackBar(
              const SnackBar(content: Text('Confirmation envoyée par e-mail')));
        }
      }));
    }
    Navigator.pop(context, true);
  }

  // --- Interface ---------------------------------------------------

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
    final vehicule = _vehiculeChoisi(donnees.vehicules);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (donnees.voyages.isEmpty)
          _bandeau('Créez d\'abord un voyage : chaque location est rattachée à l\'un de vos voyages.'),
        if (donnees.vehicules.isEmpty)
          _bandeau('Aucun véhicule disponible pour le moment.'),
        ChampChoix<int>(
          label: 'Véhicule',
          icone: Icons.directions_car_outlined,
          valeur: vehiculeValide,
          erreur: vehiculeValide == null ? _erreurChoix : null,
          items: [
            for (final v in donnees.vehicules)
              DropdownMenuItem<int>(
                value: v.id!,
                child: Row(
                  children: [
                    Icon(v.type.icone, size: 18, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${v.nom} · ${Montants.affiche(v.prixParJour)} / jour',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChange: (id) => _choisirVehicule(id, donnees.vehicules),
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
        const SizedBox(height: 20),
        _section('Dates'),
        _champDates(),
        const SizedBox(height: 10),
        _legende(vehicule),
        const SizedBox(height: 20),
        _section('Prise en charge et retour'),
        ChampTexte(
          controller: _lieuPrise,
          label: 'Lieu de prise en charge',
          icone: Icons.place_outlined,
          capitalisation: TextCapitalization.sentences,
        ),
        CheckboxListTile(
          value: _memeLieu,
          onChanged: (v) => setState(() => _memeLieu = v ?? true),
          title: const Text('Retour au même lieu'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.teal,
        ),
        if (!_memeLieu)
          ChampTexte(
            controller: _lieuRetour,
            label: 'Lieu de retour',
            icone: Icons.assistant_direction_outlined,
            capitalisation: TextCapitalization.sentences,
          ),
        if (vehicule != null && vehicule.type.motorise) ...[
          const SizedBox(height: 14),
          ChampTexte(
            controller: _permis,
            label: 'Numéro de permis de conduire',
            icone: Icons.badge_outlined,
            capitalisation: TextCapitalization.characters,
          ),
          if (_erreurPermis != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(_erreurPermis!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
        if (vehicule != null) ...[
          const SizedBox(height: 20),
          _section('Options'),
          _choixOptions(vehicule),
        ],
        const SizedBox(height: 20),
        ChampTexte(
          controller: _notes,
          label: 'Notes (heure d\'arrivée, demande particulière…)',
          icone: Icons.notes,
          clavier: TextInputType.multiline,
          lignes: 2,
          capitalisation: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        _apercu(vehicule),
        const SizedBox(height: 24),
        if (_erreurServeur != null) _bandeauErreur(_erreurServeur!),
        BoutonPrincipal(
          libelle: _modeEdition ? 'Enregistrer les modifications' : 'Confirmer la location',
          icone: Icons.check,
          onPressed: (_enregistrement || !pretAEnregistrer)
              ? null
              : () => _enregistrer(donnees),
        ),
        const SizedBox(height: 12),
        BoutonSecondaire(
          libelle: 'Annuler',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _champDates() {
    final texte = (_debut != null && _fin != null)
        ? '${periode(_debut!, _fin!)}  ·  '
            '${LocationVehicule.ecartJours(_debut!, _fin!) + 1} j'
        : 'Choisir les dates';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _chargementPeriodes ? null : _choisirDates,
          child: InputDecorator(
            decoration: decorationUi('Prise en charge → retour', icone: Icons.date_range)
                .copyWith(errorText: _erreurDates),
            child: Row(
              children: [
                Expanded(
                  child: Text(texte,
                      style: TextStyle(
                          color: _debut == null ? AppColors.grey : AppColors.navy,
                          fontWeight: FontWeight.w600)),
                ),
                if (_chargementPeriodes)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Légende du calendrier : jours indisponibles du véhicule choisi.
  Widget _legende(Vehicule? v) {
    if (v == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  border: Border.all(color: AppColors.grey),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Jours indisponibles',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              const Text('grisés dans le calendrier',
                  style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          if (_periodes.isEmpty)
            const Text('Aucune réservation à venir : toutes les dates sont libres.',
                style: TextStyle(color: AppColors.grey, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (debut, fin) in _periodes)
                  Pastille(libelle: periode(debut, fin), valeur: 'indisponible'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _choixOptions(Vehicule v) {
    final proposees = OptionLocation.pour(v.type);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in proposees)
          FilterChip(
            avatar: Icon(o.icone,
                size: 18, color: _options.contains(o) ? AppColors.white : AppColors.teal),
            label: Text('${o.libelle} · ${Montants.affiche(o.prixParJour)}/j'),
            selected: _options.contains(o),
            showCheckmark: false,
            selectedColor: AppColors.teal,
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: _options.contains(o) ? AppColors.white : AppColors.navy),
            onSelected: (oui) => setState(() {
              if (oui) {
                _options.add(o);
              } else {
                _options.remove(o);
              }
            }),
          ),
      ],
    );
  }

  /// Détail du calcul : (prix du véhicule + options) x jours, même formule que le repository.
  Widget _apercu(Vehicule? v) {
    if (v == null || _debut == null || _fin == null || _verifierDates() != null) {
      return const SizedBox.shrink();
    }
    final jours = LocationVehicule.ecartJours(_debut!, _fin!) + 1;
    final options = _optionsTriees;
    final prix = LocationVehicule.calculerPrixDynamique(
      regles: v.reglesTarif,
      prixParJour: v.prixParJour,
      options: options,
      debut: _debut!,
      fin: _fin!,
    );
    final tarif = prix.tarif;
    final total = prix.total;
    final j = '$jours j';

    Widget ajustement(String libelle, double montant) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(libelle,
                    style: const TextStyle(color: AppColors.navy, fontSize: 14)),
              ),
              Text('${montant < 0 ? '−' : '+'} ${Montants.affiche(montant.abs())}',
                  style: TextStyle(
                      color: montant < 0 ? AppColors.teal : AppColors.orangeText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );

    Widget ligne(String libelle, double parJour) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text('$libelle  ${Montants.affiche(parJour)} × $j',
                    style: const TextStyle(color: AppColors.navy, fontSize: 14)),
              ),
              Text(Montants.affiche(parJour * jours),
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        );

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
          const Text('DÉTAIL DU PRIX',
              style: TextStyle(
                  color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ligne(v.nom, v.prixParJour),
          if (tarif.majorationWeekend > 0)
            ajustement('Week-end (${tarif.joursWeekend} j, +${v.majorationWeekend.toStringAsFixed(0)} %)',
                tarif.majorationWeekend),
          if (tarif.majorationSaison > 0)
            ajustement('Haute saison (${tarif.joursSaison} j, +${v.majorationSaison.toStringAsFixed(0)} %)',
                tarif.majorationSaison),
          if (tarif.remise > 0)
            ajustement('Longue durée (−${v.remiseLongueDuree.toStringAsFixed(0)} %)', -tarif.remise),
          for (final o in options) ligne(o.libelle, o.prixParJour),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Total',
                    style: TextStyle(
                        color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text(Montants.affiche(total),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          if (v.caution > 0)
            Text('+ caution remboursable ${Montants.affiche(v.caution)}',
                style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Retour en retard : ${Montants.affiche(v.prixParJour * LocationVehicule.coefficientRetard)} '
            'par jour de retard.',
            style: const TextStyle(color: AppColors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section(String titre) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(titre.toUpperCase(),
            style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800)),
      );

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
