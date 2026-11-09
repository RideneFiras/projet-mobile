import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../email_service.dart';
import '../models/offre_vol.dart';
import '../models/voyage.dart';
import '../models/voyage_vol.dart';
import '../voyage_repository.dart';
import '../voyage_vol_repository.dart';

/// Point d'entrée unique (le routeur de l'équipe appelle toujours cette classe) :
///  - sans voyage  -> assistant « Nouveau voyage » (carte, classe, dates, récapitulatif)
///  - avec voyage  -> écran « Modifier le voyage » (titre + annulation)
/// Renvoie true à la fermeture si quelque chose a été enregistré.
class VoyageFormScreen extends StatelessWidget {
  final Voyage? voyage;

  const VoyageFormScreen({super.key, this.voyage});

  @override
  Widget build(BuildContext context) => voyage == null
      ? const NouveauVoyageScreen()
      : ModifierVoyageScreen(voyage: voyage!);
}

// ───────────────────────── Assistant « Nouveau voyage » ─────────────────────────

class NouveauVoyageScreen extends StatefulWidget {
  const NouveauVoyageScreen({super.key});

  @override
  State<NouveauVoyageScreen> createState() => _NouveauVoyageScreenState();
}

class _NouveauVoyageScreenState extends State<NouveauVoyageScreen> {
  static const _titresEtapes = ['Destination', 'Classe', 'Dates', 'Récapitulatif'];

  final _repo = VoyageVolRepository();
  final _cle = GlobalKey<FormState>();
  final _titre = TextEditingController();
  late final Future<List<OffreVol>> _futur;

  int _etape = 0;
  String? _ville;
  ClasseVol? _classe;
  OffreVol? _offre;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _futur = _repo.offres();
  }

  @override
  void dispose() {
    _titre.dispose();
    super.dispose();
  }

  /// Une offre par ville (la moins chère) : une épingle par destination.
  List<OffreVol> _destinations(List<OffreVol> tous) {
    final parVille = <String, OffreVol>{};
    for (final o in tous) {
      final deja = parVille[o.ville];
      if (deja == null || o.prixBase < deja.prixBase) parVille[o.ville] = o;
    }
    return parVille.values.toList();
  }

  OffreVol _moinsChere(List<OffreVol> offres) =>
      offres.reduce((a, b) => a.prixBase <= b.prixBase ? a : b);

  void _choisirVille(String ville) {
    setState(() {
      if (_ville != ville) {
        _ville = ville;
        _offre = null; // les dates dépendent de la ville
        _titre.clear();
      }
    });
  }

  bool get _peutContinuer => switch (_etape) {
    0 => _ville != null,
    1 => _classe != null,
    2 => _offre != null,
    _ => true,
  };

  void _suivant() {
    setState(() {
      _etape++;
      if (_etape == 3 && _titre.text.trim().isEmpty) {
        _titre.text = 'Voyage à $_ville';
      }
    });
  }

  Future<void> _confirmer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final userId = await SessionService.instance.utilisateurId();
    if (!mounted || userId == null) return;
    setState(() => _enregistrement = true);
    try {
      // 1. Sauvegarde en SQLite
      await _repo.creerVoyageAvecVol(
        titre: _titre.text.trim(),
        utilisateurId: userId,
        offre: _offre!,
        classe: _classe!,
      );

      // 2. Envoi automatique de l'e-mail de confirmation
      const String userEmail = 'dhiadridi56@gmail.com'; // Remplacez par votre e-mail de test
      final double totalPrix = _offre!.prixPour(_classe!);
      final voyageCree = Voyage(
        titre: _titre.text.trim(),
        destination: _offre!.ville,
        dateDebut: _offre!.dateDepart,
        dateFin: _offre!.dateRetour,
        budget: totalPrix,
        statut: StatutVoyage.planifie,
        utilisateurId: userId,
      );

      await EmailService.envoyerConfirmation(
        emailUtilisateur: userEmail,
        voyage: voyageCree,
        totalPrix: totalPrix,
      );

      if (!mounted) return;
      afficherMessage(context, 'Voyage créé ! E-mail de confirmation envoyé.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      afficherMessage(context, 'Enregistrement impossible : $e', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _etape == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _etape--);
      },
      child: EcranModule(
        titre: 'Nouveau voyage',
        corps: FutureBuilder<List<OffreVol>>(
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
            final tous = snap.data!;
            final offresVille =
            tous.where((o) => o.ville == _ville).toList(growable: false);
            return Column(
              children: [
                _entete(),
                Expanded(child: _contenu(tous, offresVille)),
                _pied(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Étape ${_etape + 1} sur 4  ·  ${_titresEtapes[_etape]}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_etape + 1) / 4,
              minHeight: 6,
              color: AppColors.teal,
              backgroundColor: AppColors.tealLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pied() {
    final dernier = _etape == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoutonPrincipal(
            libelle: dernier ? 'Confirmer le voyage' : 'Continuer',
            icone: dernier ? Icons.check : Icons.arrow_forward,
            onPressed: !_peutContinuer
                ? null
                : dernier
                ? (_enregistrement ? null : _confirmer)
                : _suivant,
          ),
          if (_etape > 0) ...[
            const SizedBox(height: 10),
            BoutonSecondaire(
              libelle: 'Retour',
              onPressed: () => setState(() => _etape--),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contenu(List<OffreVol> tous, List<OffreVol> offresVille) {
    return switch (_etape) {
      0 => _etapeCarte(_destinations(tous)),
      1 => _etapeClasse(offresVille),
      2 => _etapeDates(offresVille),
      _ => _etapeRecap(),
    };
  }

  Widget _etapeCarte(List<OffreVol> destinations) {
    OffreVol? choisie;
    for (final d in destinations) {
      if (d.ville == _ville) choisie = d;
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(37, 24),
                  initialZoom: 3,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.projet_mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final d in destinations)
                        Marker(
                          point: LatLng(d.latitude, d.longitude),
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            onTap: () => _choisirVille(d.ville),
                            child: _epingle(d.ville == _ville),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final d in destinations)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(d.ville),
                    selected: d.ville == _ville,
                    onSelected: (_) => _choisirVille(d.ville),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: choisie == null
              ? const Text(
            'Touchez une épingle (ou une ville) pour choisir votre destination.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          )
              : CarteModule(
            accent: AppColors.orange,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${choisie.ville}, ${choisie.pays}',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Vol estimé : ${choisie.dureeLibelle} depuis Tunis',
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('dès',
                        style: TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                    Text(Montants.affiche(choisie.prixBase),
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _epingle(bool selectionnee) {
    return Center(
      child: Container(
        width: selectionnee ? 44 : 34,
        height: selectionnee ? 44 : 34,
        decoration: BoxDecoration(
          color: selectionnee ? AppColors.orange : AppColors.teal,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)],
        ),
        child: Icon(Icons.flight, color: AppColors.white, size: selectionnee ? 22 : 17),
      ),
    );
  }

  Widget _etapeClasse(List<OffreVol> offresVille) {
    if (offresVille.isEmpty) return const SizedBox.shrink();
    final min = _moinsChere(offresVille);
    const details = {
      ClasseVol.eco: ('1 bagage cabine · repas en option', Icons.event_seat_outlined),
      ClasseVol.affaires: (
      '2 bagages · repas inclus · siège large',
      Icons.business_center_outlined
      ),
      ClasseVol.premiere: (
      'Salon d\'embarquement · siège-lit · service prioritaire',
      Icons.workspace_premium_outlined
      ),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        Text('Vol vers ${min.ville} : choisissez votre classe',
            style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        const SizedBox(height: 12),
        for (final c in ClasseVol.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CarteModule(
              accent: _classe == c ? AppColors.orange : null,
              onTap: () => setState(() => _classe = c),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: AppColors.tealLight, shape: BoxShape.circle),
                    child: Icon(details[c]!.$2, color: AppColors.teal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.libelle,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(details[c]!.$1,
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('dès',
                          style:
                          TextStyle(color: AppColors.grey, fontSize: 12)),
                      Text(Montants.affiche(min.prixPour(c)),
                          style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _etapeDates(List<OffreVol> offresVille) {
    final classe = _classe ?? ClasseVol.eco;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        Text('Départs disponibles vers $_ville · ${classe.libelle}',
            style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        const SizedBox(height: 12),
        for (final o in offresVille)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CarteModule(
              accent: _offre?.id == o.id ? AppColors.orange : null,
              onTap: () => setState(() => _offre = o),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      color: AppColors.teal),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(periode(o.dateDepart, o.dateRetour),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${o.nuits} nuits · vol ${o.dureeLibelle}',
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Text(Montants.affiche(o.prixPour(classe)),
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _etapeRecap() {
    final o = _offre!;
    final c = _classe!;
    return Form(
      key: _cle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        children: [
          ChampTexte(
            controller: _titre,
            label: 'Titre du voyage',
            icone: Icons.title,
            capitalisation: TextCapitalization.sentences,
            validateur: (v) => Validators.requis(v, champ: 'Le titre'),
          ),
          const SizedBox(height: 14),
          CarteModule(
            child: Column(
              children: [
                _Ligne(Icons.place_outlined, 'Destination', '${o.ville}, ${o.pays}'),
                _Ligne(Icons.event_outlined, 'Dates', periode(o.dateDepart, o.dateRetour)),
                _Ligne(Icons.hotel_outlined, 'Séjour', '${o.nuits} nuits'),
                _Ligne(Icons.schedule, 'Durée du vol', o.dureeLibelle),
                _Ligne(Icons.airline_seat_recline_normal, 'Classe', c.libelle),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text('Prix du billet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(Montants.affiche(o.prixPour(c)),
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Le statut passe automatiquement de « Planifié » à « En cours » puis « Terminé » selon les dates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Écran « Modifier le voyage » ─────────────────────────

class ModifierVoyageScreen extends StatefulWidget {
  final Voyage voyage;

  const ModifierVoyageScreen({super.key, required this.voyage});

  @override
  State<ModifierVoyageScreen> createState() => _ModifierVoyageScreenState();
}

class _ModifierVoyageScreenState extends State<ModifierVoyageScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = VoyageRepository();
  final _volRepo = VoyageVolRepository();
  late final TextEditingController _titre;
  late final Future<(VoyageVol, OffreVol)?> _vol;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController(text: widget.voyage.titre);
    _vol = _volRepo.volDuVoyage(widget.voyage.id!);
  }

  @override
  void dispose() {
    _titre.dispose();
    super.dispose();
  }

  Voyage _copie({required String titre, required StatutVoyage statut}) {
    final v = widget.voyage;
    return Voyage(
      id: v.id,
      titre: titre,
      destination: v.destination,
      dateDebut: v.dateDebut,
      dateFin: v.dateFin,
      budget: v.budget,
      statut: statut,
      utilisateurId: v.utilisateurId,
    );
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final userId = await SessionService.instance.utilisateurId();
    if (!mounted || userId == null) return;
    setState(() => _enregistrement = true);
    await _repo.modifier(
        _copie(titre: _titre.text, statut: widget.voyage.statut), userId);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _annuler() async {
    final ok = await confirmer(
      context,
      titre: 'Annuler ce voyage ?',
      message: '« ${widget.voyage.titre} » sera marqué comme annulé.',
      action: 'Annuler le voyage',
    );
    if (!ok || !mounted) return;
    final userId = await SessionService.instance.utilisateurId();
    if (!mounted || userId == null) return;
    await _repo.modifier(
        _copie(titre: widget.voyage.titre, statut: StatutVoyage.annule), userId);
    if (!mounted) return;
    afficherMessage(context, 'Voyage annulé');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voyage;
    final statut = v.statutEffectif;
    return EcranModule(
      titre: 'Modifier le voyage',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ChampTexte(
              controller: _titre,
              label: 'Titre du voyage',
              icone: Icons.title,
              capitalisation: TextCapitalization.sentences,
              validateur: (t) => Validators.requis(t, champ: 'Le titre'),
            ),
            const SizedBox(height: 14),
            CarteModule(
              child: FutureBuilder<(VoyageVol, OffreVol)?>(
                future: _vol,
                builder: (context, snap) {
                  final vol = snap.data;
                  return Column(
                    children: [
                      Row(
                        children: [
                          const Text('Statut',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Pastille(libelle: statut.libelle, valeur: statut.valeur),
                        ],
                      ),
                      const Divider(height: 24),
                      _Ligne(Icons.place_outlined, 'Destination', v.destination),
                      _Ligne(Icons.event_outlined, 'Dates', periode(v.dateDebut, v.dateFin)),
                      _Ligne(Icons.hotel_outlined, 'Durée', '${v.duree} jours'),
                      if (vol != null) ...[
                        _Ligne(Icons.airline_seat_recline_normal, 'Classe', vol.$1.classe.libelle),
                        _Ligne(Icons.schedule, 'Durée du vol', vol.$2.dureeLibelle),
                      ],
                      const Divider(height: 24),
                      Row(
                        children: [
                          Text(vol != null ? 'Prix du billet' : 'Budget',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(Montants.affiche(vol?.$1.prix ?? v.budget),
                              style: const TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Destination, dates et prix viennent de l\'offre choisie : seul le titre est modifiable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            BoutonPrincipal(
              libelle: 'Enregistrer',
              icone: Icons.check,
              onPressed: _enregistrement ? null : _enregistrer,
            ),
            if (v.statut != StatutVoyage.annule) ...[
              const SizedBox(height: 12),
              BoutonSecondaire(
                libelle: 'Annuler ce voyage',
                icone: Icons.block,
                onPressed: _annuler,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String valeur;

  const _Ligne(this.icone, this.libelle, this.valeur);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: AppColors.grey),
          const SizedBox(width: 10),
          Text(libelle,
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(valeur,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}