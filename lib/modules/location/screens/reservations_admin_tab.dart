import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
import '../models/statistiques_location.dart';
import '../models/vehicule.dart';
import 'contrat_screen.dart';
import 'suivi_vehicule_screen.dart';

/// Onglet administrateur « Réservations » : statistiques en haut, puis toutes les
/// locations filtrables par statut, avec les actions Annuler et Clôturer.
class ReservationsAdminTab extends StatefulWidget {
  const ReservationsAdminTab({super.key});

  @override
  State<ReservationsAdminTab> createState() => _ReservationsAdminTabState();
}

class _ReservationsAdminTabState extends State<ReservationsAdminTab> {
  final _repo = LocationRepository();
  StatutLocation? _filtre;
  late Future<StatistiquesLocation> _stats;
  late Future<List<LocationVehicule>> _locations;

  /// Filtres proposés (statut affiché).
  static const _filtres = <(StatutLocation?, String)>[
    (null, 'Toutes'),
    (StatutLocation.confirmee, 'À venir'),
    (StatutLocation.enCours, 'En cours'),
    (StatutLocation.terminee, 'Terminées'),
    (StatutLocation.annulee, 'Annulées'),
  ];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    _stats = _repo.statistiques();
    _locations = _repo.toutesLesLocations(statut: _filtre);
  }

  Future<void> _recharger() async {
    setState(_charger);
    await Future.wait([_stats, _locations]);
  }

  Future<void> _annuler(LocationVehicule l) async {
    final ok = await confirmer(
      context,
      titre: 'Annuler cette location ?',
      message: '${l.nomVehicule ?? 'Véhicule'} · ${l.nomClient ?? 'client'}\n'
          '${periode(l.dateDebut, l.dateFin)}',
    );
    if (!ok || !mounted) return;
    final fait = await _repo.annulerLocationAdmin(l.id!);
    if (!mounted) return;
    afficherMessage(context, fait ? 'Location annulée' : 'Annulation impossible',
        erreur: !fait);
    await _recharger();
  }

  Future<void> _contrat(LocationVehicule l) async {
    await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ContratScreen(locationId: l.id!)));
    if (mounted) await _recharger();
  }

  Future<void> _suivre(LocationVehicule l) async {
    final v = await _repo.vehicule(l.vehiculeId);
    if (v == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SuiviVehiculeScreen(vehicule: v, client: l.nomClient)),
    );
  }

  Future<void> _cloturer(LocationVehicule l) async {
    final vehicule = await _repo.vehicule(l.vehiculeId);
    if (!mounted || vehicule == null) return;
    final saisie = await showDialog<(DateTime, int?)>(
      context: context,
      builder: (_) => _DialogueCloture(location: l, vehicule: vehicule),
    );
    if (saisie == null || !mounted) return;
    final (dateRetour, kmRetour) = saisie;
    final erreur =
        await _repo.cloturerLocation(l.id!, dateRetour: dateRetour, kmRetour: kmRetour);
    if (!mounted) return;
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    final penalite = LocationVehicule.calculerPenalite(
        finPrevue: l.dateFin, retour: dateRetour, prixParJour: vehicule.prixParJour);
    afficherMessage(
        context,
        penalite > 0
            ? 'Location clôturée · pénalité de retard ${Montants.affiche(penalite)}'
            : 'Location clôturée');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _recharger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          FutureBuilder<StatistiquesLocation>(
            future: _stats,
            builder: (context, snap) => snap.hasData
                ? _statistiques(snap.data!)
                : const SizedBox(
                    height: 120, child: Center(child: CircularProgressIndicator())),
          ),
          const SizedBox(height: 20),
          _puces(),
          const SizedBox(height: 14),
          FutureBuilder<List<LocationVehicule>>(
            future: _locations,
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
                return const EtatVideModule(
                  icone: Icons.event_note_outlined,
                  titre: 'Aucune réservation',
                  message: 'Aucune location ne correspond à ce filtre.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EnteteSection(titre: 'Réservations (${liste.length})'),
                  const SizedBox(height: 12),
                  for (final l in liste) ...[
                    _carte(l),
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

  // --- Statistiques ------------------------------------------------

  Widget _statistiques(StatistiquesLocation s) {
    return GrilleAdaptative(
      largeurMin: 160,
      espacement: 12,
      enfants: [
        _indicateur(
          icone: Icons.directions_car_filled_outlined,
          titre: 'Locations actives',
          valeur: '${s.actives}',
          detail: '${s.enCours} en cours · ${s.enRetard} en retard',
          alerte: s.enRetard > 0,
        ),
        _indicateur(
          icone: Icons.payments_outlined,
          titre: 'Chiffre d\'affaires',
          valeur: Montants.affiche(s.chiffreAffaires),
          detail: 'Hors annulations, pénalités comprises',
        ),
        _indicateur(
          icone: Icons.emoji_events_outlined,
          titre: 'Véhicule le plus loué',
          valeur: s.vehiculePlusLoue ?? '—',
          detail: s.vehiculePlusLoue == null
              ? 'Aucune location'
              : '${s.locationsVehiculePlusLoue} location'
                  '${s.locationsVehiculePlusLoue > 1 ? 's' : ''}',
        ),
        _indicateur(
          icone: Icons.build_circle_outlined,
          titre: 'Entretien',
          valeur: '${s.enMaintenance} en maintenance',
          detail: s.revisionsDues == 0
              ? 'Aucune révision due'
              : '${s.revisionsDues} révision${s.revisionsDues > 1 ? 's' : ''} à faire',
          alerte: s.revisionsDues > 0,
        ),
        CarteModule(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Revenus par type',
                        style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.revenusParType.isEmpty)
                const Text('Aucune location', style: TextStyle(color: AppColors.grey))
              else
                for (final t in TypeVehicule.values)
                  if (s.revenusParType[t] case final ca?)
                    _barreRevenu(t, ca, s.chiffreAffaires),
            ],
          ),
        ),
        CarteModule(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.donut_large, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Occupation ${StatistiquesLocation.periodeJours} j',
                        style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.tauxOccupation.isEmpty)
                const Text('Aucun véhicule', style: TextStyle(color: AppColors.grey))
              else
                for (final t in TypeVehicule.values)
                  if (s.tauxOccupation[t] case final taux?) _barreOccupation(t, taux),
            ],
          ),
        ),
      ],
    );
  }

  Widget _indicateur({
    required IconData icone,
    required String titre,
    required String valeur,
    required String detail,
    bool alerte = false,
  }) =>
      CarteModule(
        accent: alerte ? AppColors.danger : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: AppColors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titre,
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(valeur,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(detail,
                style: TextStyle(
                    color: alerte ? AppColors.danger : AppColors.grey, fontSize: 12)),
          ],
        ),
      );

  Widget _barreRevenu(TypeVehicule type, double ca, double total) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(type.icone, size: 16, color: AppColors.navy),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total <= 0 ? 0.0 : (ca / total).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.disabled,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(Montants.affiche(ca),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );

  Widget _barreOccupation(TypeVehicule type, double taux) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(type.icone, size: 16, color: AppColors.navy),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: taux,
                  minHeight: 8,
                  backgroundColor: AppColors.disabled,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text('${(taux * 100).round()} %',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      );

  // --- Liste -------------------------------------------------------

  Widget _puces() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (statut, libelle) in _filtres)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(libelle),
                  selected: _filtre == statut,
                  showCheckmark: false,
                  selectedColor: AppColors.teal,
                  backgroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _filtre == statut ? AppColors.white : AppColors.navy,
                  ),
                  onSelected: (_) {
                    _filtre = statut;
                    _recharger();
                  },
                ),
              ),
          ],
        ),
      );

  Widget _carte(LocationVehicule l) {
    final (libelle, valeur) = l.affichageStatut;
    final details = <String>[
      periode(l.dateDebut, l.dateFin),
      '${l.jours} j',
      if (l.options.isNotEmpty) l.options.map((o) => o.libelle).join(', '),
    ];
    return CarteModule(
      accent: couleursStatut(valeur).$2,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Pastille(libelle: libelle, valeur: valeur),
            ],
          ),
          const SizedBox(height: 6),
          _ligne(Icons.person_outline,
              '${l.nomClient ?? 'Client'}${l.emailClient == null ? '' : ' · ${l.emailClient}'}'),
          _ligne(Icons.event_outlined, details.join('  ·  ')),
          if (l.lieuPrise != null)
            _ligne(
                Icons.place_outlined,
                l.lieuRetour == null || l.lieuRetour == l.lieuPrise
                    ? l.lieuPrise!
                    : '${l.lieuPrise} → ${l.lieuRetour}'),
          if (l.cloturee && l.dateRetourReelle != null)
            _ligne(
                Icons.assignment_turned_in_outlined,
                'Rendu le ${dateCourte(l.dateRetourReelle!)}'
                '${l.kmRetour == null ? '' : ' · ${l.kmDepart ?? '?'} → ${l.kmRetour} km'}'),
          if (l.contratSigneLe != null)
            _ligne(Icons.verified_outlined, 'Contrat signé le ${dateCourte(l.contratSigneLe!)}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _contrat(l),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Contrat'),
              ),
              if (l.statutEffectif == StatutLocation.enCours)
                TextButton.icon(
                  onPressed: () => _suivre(l),
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('Suivi'),
                ),
            ],
          ),
          Row(
            children: [
              Text(Montants.affiche(l.totalDu),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 16, fontWeight: FontWeight.w800)),
              if (l.penalite > 0)
                Text('  dont retard ${Montants.affiche(l.penalite)}',
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              const Spacer(),
              if (!l.annulee && !l.cloturee)
                TextButton(
                  onPressed: () => _annuler(l),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Annuler'),
                ),
              if (l.aCloturer)
                FilledButton.tonal(
                  onPressed: () => _cloturer(l),
                  child: const Text('Clôturer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligne(IconData icone, String texte) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 15, color: AppColors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(texte,
                  style: const TextStyle(color: AppColors.grey, fontSize: 13)),
            ),
          ],
        ),
      );
}

/// Saisie du retour : date réelle (entre la prise en charge et aujourd'hui)
/// et kilométrage pour une voiture ou une moto. Aperçu de la pénalité de retard.
class _DialogueCloture extends StatefulWidget {
  final LocationVehicule location;
  final Vehicule vehicule;

  const _DialogueCloture({required this.location, required this.vehicule});

  @override
  State<_DialogueCloture> createState() => _DialogueClotureState();
}

class _DialogueClotureState extends State<_DialogueCloture> {
  final _km = TextEditingController();
  late DateTime _retour;
  String? _erreur;

  int? get _kmDepart => widget.location.kmDepart ?? widget.vehicule.kilometrage;

  @override
  void initState() {
    super.initState();
    _retour = dateJour(DateTime.now());
  }

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _retour,
      firstDate: dateJour(widget.location.dateDebut),
      lastDate: dateJour(DateTime.now()),
      helpText: 'Date de retour réelle',
    );
    if (d != null) setState(() => _retour = d);
  }

  void _valider() {
    int? km;
    if (widget.vehicule.type.motorise) {
      final texte = _km.text.trim();
      if (texte.isNotEmpty) {
        km = int.tryParse(texte);
        if (km == null || km < 0) {
          setState(() => _erreur = 'Kilométrage invalide');
          return;
        }
      }
      if (km == null && _kmDepart != null) {
        setState(() => _erreur = 'Indiquez le kilométrage au retour');
        return;
      }
      if (km != null && _kmDepart != null && km < _kmDepart!) {
        setState(() => _erreur = 'Doit être au moins $_kmDepart km');
        return;
      }
    }
    Navigator.pop<(DateTime, int?)>(context, (_retour, km));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.location;
    final retard = LocationVehicule.joursDeRetard(l.dateFin, _retour);
    final penalite = LocationVehicule.calculerPenalite(
        finPrevue: l.dateFin, retour: _retour, prixParJour: widget.vehicule.prixParJour);
    return AlertDialog(
      title: const Text('Clôturer la location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.nomVehicule ?? widget.vehicule.nom} · retour prévu le ${dateCourte(l.dateFin)}',
                style: const TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_available),
              label: Text('Rendu le ${dateCourte(_retour)}'),
            ),
            if (widget.vehicule.type.motorise) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: decorationUi(
                  _kmDepart == null
                      ? 'Kilométrage au retour'
                      : 'Kilométrage au retour (départ : $_kmDepart km)',
                  icone: Icons.speed_outlined,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              retard == 0
                  ? 'Retour dans les temps : aucune pénalité.'
                  : '$retard jour${retard > 1 ? 's' : ''} de retard × '
                      '${Montants.affiche(widget.vehicule.prixParJour)} × '
                      '${LocationVehicule.coefficientRetard} = ${Montants.affiche(penalite)}',
              style: TextStyle(
                  color: retard == 0 ? AppColors.teal : AppColors.danger,
                  fontWeight: FontWeight.w600),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        FilledButton(onPressed: _valider, child: const Text('Clôturer')),
      ],
    );
  }
}
