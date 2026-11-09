import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/hugging_face_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/calendrier_disponibilite.dart';
import '../../../core/widgets/carte_emplacement.dart';
import '../../../core/widgets/galerie_photos.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_ia_service.dart';
import '../location_repository.dart';
import '../models/blocage_vehicule.dart';
import '../models/vehicule.dart';
import 'location_form_screen.dart';
import 'vehicule_form_screen.dart';

/// Fiche d'un véhicule : photos, caractéristiques, emplacement, calendrier des
/// disponibilités (réservation rapide), avis et résumé par l'IA.
/// Voyageur : « Réserver ». Administrateur ([gestion]) : modifier, statut, dates bloquées,
/// révision, contrôle des photos (Hugging Face).
/// Renvoie true à la fermeture si le véhicule a été modifié.
class VehiculeDetailScreen extends StatefulWidget {
  final int vehiculeId;
  final bool gestion;

  const VehiculeDetailScreen({super.key, required this.vehiculeId, this.gestion = false});

  @override
  State<VehiculeDetailScreen> createState() => _VehiculeDetailScreenState();
}

typedef _Fiche = (
  Vehicule?,
  List<(DateTime, DateTime)>,
  List<BlocageVehicule>,
  List<({int note, String? commentaire})>,
);

class _VehiculeDetailScreenState extends State<VehiculeDetailScreen> {
  final _repo = LocationRepository();
  final _ia = LocationIaService();
  late Future<_Fiche> _futur;
  bool _modifie = false;
  bool _travail = false;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<_Fiche> _charger() async => (
        await _repo.vehicule(widget.vehiculeId),
        await _repo.periodesReservees(widget.vehiculeId),
        await _repo.blocagesDe(widget.vehiculeId),
        await _repo.avisVehicule(widget.vehiculeId),
      );

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _modifier(Vehicule v) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VehiculeFormScreen(vehicule: v)),
    );
    if (ok == true && mounted) {
      _modifie = true;
      await _recharger();
    }
  }

  Future<void> _changerStatut(StatutVehicule s) async {
    await _repo.changerStatutVehicule(widget.vehiculeId, s);
    if (!mounted) return;
    _modifie = true;
    afficherMessage(context, 'Statut : ${s.libelle}');
    await _recharger();
  }

  Future<void> _reserver(Vehicule v, {DateTimeRange? plage}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationFormScreen(
          vehiculeId: v.id,
          dateDebut: plage?.start,
          dateFin: plage?.end,
        ),
      ),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Location enregistrée');
      await _recharger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (aFerme, _) {
        if (!aFerme) Navigator.pop(context, _modifie);
      },
      child: FutureBuilder<_Fiche>(
        future: _futur,
        builder: (context, snap) {
          final v = snap.data?.$1;
          return EcranModule(
            titre: v?.nom ?? 'Véhicule',
            actions: (widget.gestion && v != null)
                ? [
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _modifier(v),
                    ),
                    PopupMenuButton<StatutVehicule>(
                      tooltip: 'Changer le statut',
                      icon: const Icon(Icons.tune),
                      onSelected: _changerStatut,
                      itemBuilder: (_) => [
                        for (final s in StatutVehicule.values)
                          CheckedPopupMenuItem(
                            value: s,
                            checked: s == v.statut,
                            child: Text(s.libelle),
                          ),
                      ],
                    ),
                  ]
                : null,
            corps: _corps(snap),
          );
        },
      ),
    );
  }

  Widget _corps(AsyncSnapshot<_Fiche> snap) {
    if (snap.hasError) {
      return EtatVideModule(
        icone: Icons.error_outline,
        titre: 'Chargement impossible',
        message: '${snap.error}',
      );
    }
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final (v, periodes, blocages, avis) = snap.data!;
    if (v == null) {
      return const EtatVideModule(
        icone: Icons.search_off,
        titre: 'Véhicule introuvable',
        message: 'Il a peut-être été retiré de la flotte.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GaleriePhotos(photos: v.photos, iconeParDefaut: v.type.icone),
        const SizedBox(height: 16),
        _entete(v),
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Caractéristiques'),
        const SizedBox(height: 10),
        _caracteristiques(v),
        if (v.description != null) ...[
          const SizedBox(height: 20),
          const EnteteSection(titre: 'Description'),
          const SizedBox(height: 8),
          Text(v.description!,
              style: const TextStyle(color: AppColors.navy, fontSize: 14, height: 1.4)),
        ],
        if (v.aPosition || v.adresse != null) ...[
          const SizedBox(height: 20),
          const EnteteSection(titre: 'Prise en charge'),
          const SizedBox(height: 8),
          if (v.adresse != null)
            _ligne(Icons.place_outlined, v.adresse!),
          if (v.aPosition) ...[
            const SizedBox(height: 10),
            CarteEmplacement(
              latitude: v.latitude!,
              longitude: v.longitude!,
              icone: v.type.icone,
            ),
          ],
        ],
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Disponibilités'),
        const SizedBox(height: 4),
        if (!widget.gestion && v.disponible)
          const Text('Touchez le premier puis le dernier jour pour réserver.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        CalendrierDisponibilite(
          estIndisponible: (j) => periodes.any(
              (p) => !j.isBefore(dateJour(p.$1)) && !j.isAfter(dateJour(p.$2))),
          onPlage: (!widget.gestion && v.disponible)
              ? (plage) => _reserver(v, plage: plage)
              : null,
        ),
        const SizedBox(height: 20),
        EnteteSection(
          titre: 'Avis (${avis.length})',
          action: avis.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: _travail ? null : () => _resumerAvis(avis),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Résumé IA'),
                ),
        ),
        const SizedBox(height: 8),
        if (avis.isEmpty)
          _ligne(Icons.rate_review_outlined, 'Aucun avis : notez ce véhicule depuis le forum.')
        else
          for (final a in avis.take(3))
            _ligne(Icons.star_rounded,
                '${a.note}/5${a.commentaire == null ? '' : ' · ${a.commentaire}'}'),
        if (widget.gestion) ..._gestion(v, blocages),
        const SizedBox(height: 28),
        if (!widget.gestion)
          BoutonPrincipal(
            libelle: v.disponible
                ? 'Réserver · ${Montants.affiche(v.prixParJour)} / jour'
                : 'Indisponible (${v.statut.libelle.toLowerCase()})',
            icone: Icons.event_available,
            onPressed: v.disponible ? () => _reserver(v) : null,
          ),
      ],
    );
  }

  // --- IA ---------------------------------------------------------

  Future<void> _resumerAvis(List<({int note, String? commentaire})> avis) async {
    setState(() => _travail = true);
    try {
      final r = await _ia.resumerAvis(avis);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ce qu\'en disent les clients'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.resume),
                if (r.positifs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final p in r.positifs) Text('👍 $p'),
                ],
                if (r.negatifs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final n in r.negatifs) Text('👎 $n'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        ),
      );
    } on IaException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _travail = false);
    }
  }

  /// Contrôle des 3 premières photos (URL) par un modèle de vision Hugging Face.
  Future<void> _analyserPhotos(Vehicule v) async {
    final hf = HuggingFaceService();
    final urls = v.photos.where((p) => p.startsWith('http')).take(3).toList();
    if (urls.isEmpty) {
      afficherMessage(context, 'Ajoutez des photos par URL pour les analyser.', erreur: true);
      return;
    }
    setState(() => _travail = true);
    final lignes = <String>[];
    try {
      for (final url in urls) {
        final image = await hf.telecharger(url);
        if (image == null) {
          lignes.add('Photo ${lignes.length + 1} : téléchargement impossible.');
          continue;
        }
        final etiquettes = await hf.analyser(image, modele: LocationIaService.modelePhotos);
        final lecture = LocationIaService.interpreterEtiquettes(etiquettes, v.type);
        lignes.add('Photo ${lignes.length + 1} : '
            '${lecture.dommage ? '⚠ dommage possible' : 'aucun dommage signalé'} · '
            '${lecture.vehiculeVisible ? '${v.type.libelle.toLowerCase()} visible' : '${v.type.libelle.toLowerCase()} non reconnu'}'
            '${etiquettes.isEmpty ? '' : ' (${etiquettes.take(3).map((e) => '${e.label} ${(e.score * 100).round()} %').join(', ')})'}');
      }
    } on IaException catch (e) {
      lignes.add(e.message);
    }
    if (!mounted) return;
    setState(() => _travail = false);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contrôle des photos'),
        content: SingleChildScrollView(child: Text(lignes.join('\n\n'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  // --- Gestion (administrateur) -----------------------------------

  List<Widget> _gestion(Vehicule v, List<BlocageVehicule> blocages) {
    final depuis = v.kmDepuisRevision;
    return [
      const SizedBox(height: 20),
      const EnteteSection(titre: 'Entretien'),
      const SizedBox(height: 8),
      if (!v.type.motorise)
        _ligne(Icons.pedal_bike, 'Pas de suivi kilométrique pour une bicyclette.')
      else if (depuis == null)
        _ligne(Icons.speed_outlined, 'Kilométrage inconnu : renseignez-le dans la fiche.')
      else ...[
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (depuis / v.intervalleRevision).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: AppColors.disabled,
                  color: v.revisionDue
                      ? AppColors.danger
                      : (v.revisionProche ? AppColors.orange : AppColors.teal),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$depuis / ${v.intervalleRevision} km',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                  v.revisionDue
                      ? 'Révision à faire maintenant.'
                      : 'Prochaine révision dans ${v.intervalleRevision - depuis} km.',
                  style: TextStyle(
                      color: v.revisionDue ? AppColors.danger : AppColors.grey,
                      fontSize: 13)),
            ),
            TextButton.icon(
              onPressed: () => _marquerRevision(v),
              icon: const Icon(Icons.build_outlined, size: 18),
              label: const Text('Révision faite'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      EnteteSection(
        titre: 'Dates bloquées',
        action: TextButton.icon(
          onPressed: () => _bloquer(v),
          icon: const Icon(Icons.block, size: 18),
          label: const Text('Bloquer'),
        ),
      ),
      const SizedBox(height: 8),
      if (blocages.isEmpty)
        _ligne(Icons.event_available, 'Aucune date bloquée.')
      else
        for (final b in blocages)
          Row(
            children: [
              Expanded(
                child: _ligne(Icons.event_busy,
                    '${periode(b.dateDebut, b.dateFin)}${b.motif == null ? '' : ' · ${b.motif}'}'),
              ),
              IconButton(
                tooltip: 'Débloquer',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () async {
                  await _repo.supprimerBlocage(b.id!);
                  if (mounted) await _recharger();
                },
              ),
            ],
          ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _travail ? null : () => _analyserPhotos(v),
        icon: const Icon(Icons.image_search),
        label: const Text('Contrôler les photos (IA)'),
      ),
    ];
  }

  Future<void> _marquerRevision(Vehicule v) async {
    final ok = await confirmer(context,
        titre: 'Révision effectuée ?',
        message: 'Le compteur de révision repart de ${v.kilometrage} km.');
    if (!ok || !mounted) return;
    await _repo.marquerRevision(v.id!);
    if (!mounted) return;
    _modifie = true;
    afficherMessage(context, 'Révision enregistrée');
    await _recharger();
  }

  Future<void> _bloquer(Vehicule v) async {
    final auj = dateJour(DateTime.now());
    final plage = await showDateRangePicker(
      context: context,
      firstDate: auj,
      lastDate: DateTime(auj.year + 2, 12, 31),
      helpText: 'Période à bloquer',
    );
    if (plage == null || !mounted) return;
    final motif = TextEditingController();
    final valide = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bloquer ${periode(plage.start, plage.end)}'),
        content: TextField(
          controller: motif,
          decoration: decorationUi('Motif (entretien, réparation…)', icone: Icons.notes),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bloquer')),
        ],
      ),
    );
    final texteMotif = motif.text;
    motif.dispose();
    if (valide != true || !mounted) return;
    final erreur = await _repo.ajouterBlocage(BlocageVehicule(
        vehiculeId: v.id!, dateDebut: plage.start, dateFin: plage.end, motif: texteMotif));
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Dates bloquées', erreur: erreur != null);
    if (erreur == null) await _recharger();
  }

  Widget _entete(Vehicule v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pastille(libelle: v.type.libelle, valeur: 'type'),
                    v.disponible && v.enLocation
                        ? const Pastille(libelle: 'Loué aujourd\'hui', valeur: 'loue')
                        : Pastille(libelle: v.statut.libelle, valeur: v.statut.valeur),
                  ],
                ),
                const SizedBox(height: 8),
                Text(v.nom,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
                if (v.nbAvis > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.orange, size: 18),
                      const SizedBox(width: 2),
                      Text('${v.noteMoyenne.toStringAsFixed(1)} · ${v.nbAvis} avis',
                          style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Montants.affiche(v.prixParJour),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('par jour', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
        ],
      );

  Widget _caracteristiques(Vehicule v) {
    final infos = <(IconData, String, String)>[
      (v.type.icone, 'Type', v.type.libelle),
      if (v.annee != null) (Icons.calendar_month_outlined, 'Année', '${v.annee}'),
      if (v.couleur != null) (Icons.palette_outlined, 'Couleur', v.couleur!),
      if (v.immatriculation != null)
        (Icons.badge_outlined, 'Immatriculation', v.immatriculation!),
      (Icons.local_gas_station_outlined, 'Motorisation', v.carburant.libelle),
      if (v.boite != null) (Icons.settings_outlined, 'Boîte', v.boite!.libelle),
      (Icons.event_seat_outlined, 'Places', '${v.places}'),
      if (v.kilometrage != null)
        (Icons.speed_outlined, 'Kilométrage', '${v.kilometrage} km'),
      (Icons.shield_outlined, 'Caution', Montants.affiche(v.caution)),
    ];
    return GrilleAdaptative(
      largeurMin: 150,
      espacement: 10,
      enfants: [
        for (final (icone, libelle, valeur) in infos)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icone, color: AppColors.teal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libelle,
                          style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                      Text(valeur,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ligne(IconData icone, String texte) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icone, size: 18, color: AppColors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  style: const TextStyle(color: AppColors.navy, fontSize: 14)),
            ),
          ],
        ),
      );
}
