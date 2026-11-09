import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../voyage/models/voyage.dart';
import '../../voyage/voyage_repository.dart';
import '../hebergement_repository.dart';
import '../models/hebergement.dart';
import '../models/reservation_hebergement.dart';

/// Réservation d'un séjour dans un hébergement pour un de vos voyages.
/// Le prix = prix par nuit x nuits ; le départ doit suivre l'arrivée.
class SejourFormScreen extends StatefulWidget {
  final ReservationHebergement? sejour;

  /// Établissement préchoisi (ouverture depuis l'onglet Établissements).
  final int? hebergementId;

  /// Dates préchoisies (calendrier de la fiche ou filtres de recherche).
  final DateTime? dateArrivee;
  final DateTime? dateDepart;

  const SejourFormScreen(
      {super.key, this.sejour, this.hebergementId, this.dateArrivee, this.dateDepart});

  @override
  State<SejourFormScreen> createState() => _SejourFormScreenState();
}

class _Donnees {
  final List<Hebergement> hebergements;
  final List<Voyage> voyages;
  final int? utilisateurId;

  const _Donnees(this.hebergements, this.voyages, this.utilisateurId);
}

class _SejourFormScreenState extends State<SejourFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = HebergementRepository();
  late final TextEditingController _personnes;
  late final TextEditingController _chambres;
  late final TextEditingController _demandes;
  late Future<_Donnees> _donnees;
  int? _hebergementId;
  int? _voyageId;
  DateTime? _arrivee;
  DateTime? _depart;
  TypeChambre _typeChambre = TypeChambre.chambreDouble;
  String? _erreurDates;
  String? _erreurChoix;
  String? _erreurServeur;
  bool _enregistrement = false;

  bool get _modeEdition => widget.sejour != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sejour;
    _personnes = TextEditingController(text: '${s?.nbPersonnes ?? 1}');
    _chambres = TextEditingController(text: '${s?.nbChambres ?? 1}');
    // L'estimation suit le nombre de chambres saisi.
    _chambres.addListener(() {
      if (mounted) setState(() {});
    });
    _demandes = TextEditingController(text: s?.demandes ?? '');
    _hebergementId = s?.hebergementId ?? widget.hebergementId;
    _voyageId = s?.voyageId;
    _arrivee = s?.dateArrivee ?? widget.dateArrivee;
    _depart = s?.dateDepart ?? widget.dateDepart;
    _typeChambre = s?.typeChambre ?? TypeChambre.chambreDouble;
    _donnees = _charger();
  }

  @override
  void dispose() {
    _personnes.dispose();
    _chambres.dispose();
    _demandes.dispose();
    super.dispose();
  }

  Future<_Donnees> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    // Établissements ouverts + celui du séjour modifié.
    final hebergements = (await HebergementRepository().hebergements())
        .where((h) => h.ouvert || h.id == _hebergementId)
        .toList();
    final voyages =
        id == null ? <Voyage>[] : await VoyageRepository().voyagesDe(id);
    return _Donnees(hebergements, voyages, id);
  }

  String? _verifierDates() {
    if (_arrivee == null || _depart == null) return 'Choisissez les deux dates';
    return ReservationHebergement.verifierSejour(_arrivee!, _depart!);
  }

  String? _validerPersonnes(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Nombre de personnes invalide';
    if (n < 1 || n > 50) return 'Entre 1 et 50 personnes';
    return null;
  }

  String? _validerChambres(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1 || n > 50) return 'Entre 1 et 50 chambres';
    return null;
  }

  int get _nbChambres => int.tryParse(_chambres.text.trim()) ?? 1;

  Future<void> _enregistrer(int? utilisateurId) async {
    final dates = _verifierDates();
    final choix = (_hebergementId == null || _voyageId == null)
        ? 'Choisissez un établissement et un voyage'
        : null;
    final formOk = _cle.currentState?.validate() ?? false;
    setState(() {
      _erreurDates = dates;
      _erreurChoix = choix;
      _erreurServeur = null;
    });
    if (!formOk || dates != null || choix != null) return;

    setState(() => _enregistrement = true);
    final erreur = await _repo.enregistrerSejour(ReservationHebergement(
      id: widget.sejour?.id,
      dateArrivee: _arrivee!,
      dateDepart: _depart!,
      nbPersonnes: int.parse(_personnes.text.trim()),
      nbChambres: _nbChambres,
      typeChambre: _typeChambre,
      demandes: _demandes.text,
      statut: widget.sejour?.statut ?? StatutSejour.confirmee,
      creeLe: widget.sejour?.creeLe,
      voyageId: _voyageId!,
      hebergementId: _hebergementId!,
    ), utilisateurId: utilisateurId);
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
      titre: _modeEdition ? 'Modifier le séjour' : 'Réserver un séjour',
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
    final hebergementValide =
        donnees.hebergements.any((h) => h.id == _hebergementId) ? _hebergementId : null;
    final voyageValide =
        donnees.voyages.any((v) => v.id == _voyageId) ? _voyageId : null;
    final pretAEnregistrer =
        donnees.hebergements.isNotEmpty && donnees.voyages.isNotEmpty;
    final hebergement = _hebergementChoisi(donnees.hebergements);

    return Form(
      key: _cle,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (donnees.voyages.isEmpty)
            _bandeau('Créez d\'abord un voyage : chaque séjour est rattaché à l\'un de vos voyages.'),
          if (donnees.hebergements.isEmpty)
            _bandeau('Ajoutez d\'abord un établissement dans l\'onglet Établissements.'),
          ChampChoix<int>(
            label: 'Établissement',
            icone: Icons.bed_outlined,
            valeur: hebergementValide,
            erreur: hebergementValide == null ? _erreurChoix : null,
            items: [
              for (final h in donnees.hebergements)
                DropdownMenuItem<int>(
                  value: h.id!,
                  child: Row(
                    children: [
                      Icon(h.type.icone, size: 18, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${h.nom} · ${Montants.affiche(h.prixParNuit)} / nuit',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            onChange: (id) => setState(() => _hebergementId = id),
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
            label: 'Arrivée',
            valeur: _arrivee,
            erreur: _erreurDates,
            onChoisie: (date) => setState(() {
              _arrivee = date;
              _erreurDates = null;
            }),
          ),
          const SizedBox(height: 14),
          ChampDate(
            label: 'Départ',
            valeur: _depart,
            erreur: _erreurDates,
            premiereDate: _arrivee,
            onChoisie: (date) => setState(() {
              _depart = date;
              _erreurDates = null;
            }),
          ),
          const SizedBox(height: 14),
          ChampTexte(
            controller: _personnes,
            label: 'Nombre de personnes',
            icone: Icons.group_outlined,
            clavier: TextInputType.number,
            validateur: _validerPersonnes,
          ),
          const SizedBox(height: 14),
          ChampChoix<TypeChambre>(
            label: 'Type de chambre',
            icone: Icons.king_bed_outlined,
            valeur: _typeChambre,
            items: [
              for (final t in TypeChambre.values)
                DropdownMenuItem(
                  value: t,
                  child: Text('${t.libelle} · ${t.personnesConseillees} pers. · ${t.libelleTarif}'),
                ),
            ],
            onChange: (t) => setState(() => _typeChambre = t ?? _typeChambre),
          ),
          const SizedBox(height: 14),
          ChampTexte(
            controller: _chambres,
            label: hebergement == null
                ? 'Nombre de chambres'
                : 'Nombre de chambres (${hebergement.capacite} pers. max / chambre)',
            icone: Icons.meeting_room_outlined,
            clavier: TextInputType.number,
            validateur: _validerChambres,
          ),
          const SizedBox(height: 14),
          ChampTexte(
            controller: _demandes,
            label: 'Demandes particulières (facultatif)',
            icone: Icons.notes,
            clavier: TextInputType.multiline,
            lignes: 2,
            capitalisation: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          _apercu(hebergement),
          const SizedBox(height: 24),
          if (_erreurServeur != null) _bandeauErreur(_erreurServeur!),
          BoutonPrincipal(
            libelle: _modeEdition ? 'Enregistrer les modifications' : 'Confirmer le séjour',
            icone: Icons.check,
            onPressed: (_enregistrement || !pretAEnregistrer)
                ? null
                : () => _enregistrer(donnees.utilisateurId),
          ),
          const SizedBox(height: 12),
          BoutonSecondaire(
            libelle: 'Annuler',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Hebergement? _hebergementChoisi(List<Hebergement> liste) {
    for (final h in liste) {
      if (h.id == _hebergementId) return h;
    }
    return null;
  }

  /// Estimation affichée dès que l'établissement et les dates sont valides.
  Widget _apercu(Hebergement? h) {
    if (h == null || _arrivee == null || _depart == null || _verifierDates() != null) {
      return const SizedBox.shrink();
    }
    final nuits = nombreDeJours(_arrivee!, _depart!);
    final chambres = _nbChambres;
    final prix = ReservationHebergement.calculerPrix(
      regles: h.reglesTarif,
      prixParNuit: h.prixParNuit,
      typeChambre: _typeChambre,
      nbChambres: chambres,
      arrivee: _arrivee!,
      depart: _depart!,
    );
    final tarif = prix.tarif;
    final total = prix.total;
    final prixChambre = h.prixParNuit * _typeChambre.coefficient;
    Widget ajustement(String libelle, double montant) => Text(
          '$libelle : ${montant < 0 ? '−' : '+'} ${Montants.affiche(montant.abs())}'
          '${chambres > 1 ? ' par chambre' : ''}',
          style: TextStyle(
              color: montant < 0 ? AppColors.teal : AppColors.orangeText, fontSize: 13),
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
          const Text('ESTIMATION',
              style: TextStyle(
                  color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '$nuits nuit${nuits > 1 ? 's' : ''} × ${Montants.affiche(prixChambre)}'
            ' (${_typeChambre.libelle.toLowerCase()})'
            '${chambres > 1 ? ' × $chambres chambres' : ''}',
            style: const TextStyle(
                color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (tarif.majorationWeekend > 0)
            ajustement('Week-end (${tarif.joursWeekend} nuit${tarif.joursWeekend > 1 ? 's' : ''})',
                tarif.majorationWeekend),
          if (tarif.majorationSaison > 0)
            ajustement('Haute saison (${tarif.joursSaison} nuit${tarif.joursSaison > 1 ? 's' : ''})',
                tarif.majorationSaison),
          if (tarif.remise > 0) ajustement('Remise longue durée', -tarif.remise),
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
