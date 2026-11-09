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
import '../hebergement_ia_service.dart';
import '../hebergement_repository.dart';
import '../models/blocage_hebergement.dart';
import '../models/hebergement.dart';
import 'etoiles.dart';
import 'hebergement_form_screen.dart';
import 'sejour_form_screen.dart';

/// Fiche d'un établissement : photos, infos pratiques, règles, équipements, carte,
/// calendrier des disponibilités (réservation rapide), avis (répartition des notes,
/// résumé par l'IA) et concierge IA.
/// Voyageur : « Réserver un séjour ». Administrateur ([gestion]) : modifier, statut,
/// fermetures, contrôle des photos (Hugging Face).
/// Renvoie true à la fermeture si l'établissement a été modifié.
class HebergementDetailScreen extends StatefulWidget {
  final int hebergementId;
  final bool gestion;

  /// Dates déjà choisies dans la recherche (pré-remplies à la réservation).
  final DateTime? arrivee;
  final DateTime? depart;

  const HebergementDetailScreen({
    super.key,
    required this.hebergementId,
    this.gestion = false,
    this.arrivee,
    this.depart,
  });

  @override
  State<HebergementDetailScreen> createState() => _HebergementDetailScreenState();
}

typedef _Fiche = (
  Hebergement?,
  List<AvisHebergement>,
  Map<int, int>,
  Set<DateTime>,
  List<BlocageHebergement>,
);

class _HebergementDetailScreenState extends State<HebergementDetailScreen> {
  final _repo = HebergementRepository();
  final _ia = HebergementIaService();
  late Future<_Fiche> _futur;
  bool _modifie = false;
  bool _travail = false;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<_Fiche> _charger() async => (
        await _repo.hebergement(widget.hebergementId),
        await _repo.avisDe(widget.hebergementId, limite: 50),
        await _repo.distributionNotes(widget.hebergementId),
        await _repo.nuitsIndisponibles(widget.hebergementId),
        await _repo.blocagesDe(widget.hebergementId),
      );

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _modifier(Hebergement h) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HebergementFormScreen(hebergement: h)),
    );
    if (ok == true && mounted) {
      _modifie = true;
      await _recharger();
    }
  }

  Future<void> _changerStatut(StatutHebergement s) async {
    await _repo.changerStatut(widget.hebergementId, s);
    if (!mounted) return;
    _modifie = true;
    afficherMessage(context, 'Statut : ${s.libelle}');
    await _recharger();
  }

  Future<void> _reserver(Hebergement h, {DateTime? arrivee, DateTime? depart}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SejourFormScreen(
          hebergementId: h.id,
          dateArrivee: arrivee ?? widget.arrivee,
          dateDepart: depart ?? widget.depart,
        ),
      ),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Séjour réservé');
      await _recharger();
    }
  }

  // --- IA ---------------------------------------------------------

  Future<void> _resumerAvis(List<AvisHebergement> avis) async {
    setState(() => _travail = true);
    try {
      final r = await _ia.resumerAvis(
          [for (final a in avis) (note: a.note, commentaire: a.commentaire)]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ce qu\'en disent les voyageurs'),
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

  void _ouvrirConcierge(Hebergement h) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _Concierge(hebergement: h, ia: _ia),
      );

  /// Probabilité que chaque photo (URL) soit générée par IA (Hugging Face).
  Future<void> _verifierPhotos(Hebergement h) async {
    final hf = HuggingFaceService();
    final urls = h.photos.where((p) => p.startsWith('http')).take(4).toList();
    if (urls.isEmpty) {
      afficherMessage(context, 'Ajoutez des photos par URL pour les vérifier.', erreur: true);
      return;
    }
    setState(() => _travail = true);
    final lignes = <String>[];
    try {
      for (final (i, url) in urls.indexed) {
        final image = await hf.telecharger(url);
        if (image == null) {
          lignes.add('Photo ${i + 1} : téléchargement impossible.');
          continue;
        }
        final p = HebergementIaService.probabiliteArtificielle(
            await hf.analyser(image, modele: HebergementIaService.modeleFaussesPhotos));
        lignes.add('Photo ${i + 1} : ${p >= 0.7 ? '⚠ probablement générée par IA' : 'semble authentique'}'
            ' (${(p * 100).round()} % artificielle)');
      }
    } on IaException catch (e) {
      lignes.add(e.message);
    }
    if (!mounted) return;
    setState(() => _travail = false);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vérification des photos'),
        content: SingleChildScrollView(child: Text(lignes.join('\n\n'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  // --- Fermetures (administrateur) --------------------------------

  Future<void> _fermer(Hebergement h) async {
    final auj = dateJour(DateTime.now());
    final plage = await showDateRangePicker(
      context: context,
      firstDate: auj,
      lastDate: DateTime(auj.year + 2, 12, 31),
      helpText: 'Période de fermeture',
    );
    if (plage == null || !mounted) return;
    final motif = TextEditingController();
    final valide = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Fermer ${periode(plage.start, plage.end)}'),
        content: TextField(
          controller: motif,
          decoration: decorationUi('Motif (travaux, saison…)', icone: Icons.notes),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fermer')),
        ],
      ),
    );
    final texteMotif = motif.text;
    motif.dispose();
    if (valide != true || !mounted) return;
    final erreur = await _repo.ajouterBlocage(BlocageHebergement(
        hebergementId: h.id!, dateDebut: plage.start, dateFin: plage.end, motif: texteMotif));
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Fermeture enregistrée', erreur: erreur != null);
    if (erreur == null) await _recharger();
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
          final h = snap.data?.$1;
          return EcranModule(
            titre: h?.nom ?? 'Établissement',
            actions: (widget.gestion && h != null)
                ? [
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _modifier(h),
                    ),
                    PopupMenuButton<StatutHebergement>(
                      tooltip: 'Changer le statut',
                      icon: const Icon(Icons.tune),
                      onSelected: _changerStatut,
                      itemBuilder: (_) => [
                        for (final s in StatutHebergement.values)
                          CheckedPopupMenuItem(
                            value: s,
                            checked: s == h.statut,
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
    final (h, avis, distribution, nuitsPrises, blocages) = snap.data!;
    if (h == null) {
      return const EtatVideModule(
        icone: Icons.search_off,
        titre: 'Établissement introuvable',
        message: 'Il a peut-être été retiré du catalogue.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GaleriePhotos(photos: h.photos, iconeParDefaut: h.type.icone),
        const SizedBox(height: 16),
        _entete(h),
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Infos pratiques'),
        const SizedBox(height: 10),
        _infos(h),
        if (h.regles != null) ...[
          const SizedBox(height: 20),
          const EnteteSection(titre: 'Règles de la maison'),
          const SizedBox(height: 8),
          Text(h.regles!,
              style: const TextStyle(color: AppColors.navy, fontSize: 14, height: 1.4)),
        ],
        if (h.description != null) ...[
          const SizedBox(height: 20),
          const EnteteSection(titre: 'Description'),
          const SizedBox(height: 8),
          Text(h.description!,
              style: const TextStyle(color: AppColors.navy, fontSize: 14, height: 1.4)),
        ],
        if (h.equipements.isNotEmpty) ...[
          const SizedBox(height: 20),
          const EnteteSection(titre: 'Équipements'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in h.equipements)
                Chip(
                  avatar: Icon(e.icone, size: 18, color: AppColors.teal),
                  label: Text(e.libelle),
                  backgroundColor: AppColors.tealLight,
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                      color: AppColors.navy, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Emplacement'),
        const SizedBox(height: 8),
        _ligne(Icons.place_outlined, h.adresseComplete),
        if (h.aPosition) ...[
          const SizedBox(height: 10),
          CarteEmplacement(
            latitude: h.latitude!,
            longitude: h.longitude!,
            icone: h.type.icone,
          ),
        ],
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Disponibilités'),
        const SizedBox(height: 4),
        if (!widget.gestion && h.ouvert)
          const Text('Touchez la date d\'arrivée puis celle du départ pour réserver.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        CalendrierDisponibilite(
          modeNuits: true,
          estIndisponible: (j) => nuitsPrises.contains(j),
          onPlage: (!widget.gestion && h.ouvert)
              ? (plage) => _reserver(h, arrivee: plage.start, depart: plage.end)
              : null,
        ),
        const SizedBox(height: 20),
        EnteteSection(
          titre: 'Avis (${h.nbAvis})',
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
          _ligne(Icons.rate_review_outlined,
              'Aucun avis pour le moment. Notez votre séjour depuis le forum.')
        else ...[
          _distribution(distribution),
          const SizedBox(height: 12),
          for (final a in avis.take(5)) ...[
            _avis(a),
            const SizedBox(height: 10),
          ],
        ],
        if (!widget.gestion) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _ouvrirConcierge(h),
            icon: const Icon(Icons.support_agent),
            label: const Text('Poser une question au concierge IA'),
          ),
        ],
        if (widget.gestion) ...[
          const SizedBox(height: 20),
          EnteteSection(
            titre: 'Fermetures',
            action: TextButton.icon(
              onPressed: () => _fermer(h),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Fermer des dates'),
            ),
          ),
          const SizedBox(height: 8),
          if (blocages.isEmpty)
            _ligne(Icons.event_available, 'Aucune fermeture prévue.')
          else
            for (final b in blocages)
              Row(
                children: [
                  Expanded(
                    child: _ligne(Icons.event_busy,
                        '${periode(b.dateDebut, b.dateFin)}${b.motif == null ? '' : ' · ${b.motif}'}'),
                  ),
                  IconButton(
                    tooltip: 'Rouvrir',
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () async {
                      await _repo.supprimerBlocage(b.id!);
                      if (mounted) await _recharger();
                    },
                  ),
                ],
              ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _travail ? null : () => _verifierPhotos(h),
            icon: const Icon(Icons.image_search),
            label: const Text('Vérifier l\'authenticité des photos (IA)'),
          ),
        ],
        const SizedBox(height: 28),
        if (!widget.gestion)
          BoutonPrincipal(
            libelle: h.ouvert
                ? 'Réserver · ${Montants.affiche(h.prixParNuit)} / nuit'
                : 'Réservations fermées (${h.statut.libelle.toLowerCase()})',
            icone: Icons.event_available,
            onPressed: h.ouvert ? () => _reserver(h) : null,
          ),
      ],
    );
  }

  /// Répartition des notes en barres horizontales (5 ★ en haut).
  Widget _distribution(Map<int, int> d) {
    final total = d.values.fold(0, (a, b) => a + b);
    return Column(
      children: [
        for (var n = 5; n >= 1; n--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text('$n ★',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0.0 : (d[n] ?? 0) / total,
                      minHeight: 8,
                      backgroundColor: AppColors.disabled,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                SizedBox(
                    width: 32,
                    child: Text('${d[n] ?? 0}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: AppColors.grey))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _entete(Hebergement h) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pastille(libelle: h.type.libelle, valeur: 'type'),
                    Pastille(libelle: h.statut.libelle, valeur: h.statut.valeur),
                    if (h.etoiles != null) Etoiles(nombre: h.etoiles!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(h.nom,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
                if (h.nbAvis > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.orange, size: 18),
                      const SizedBox(width: 2),
                      Text('${h.noteMoyenne.toStringAsFixed(1)} / 5 · ${h.nbAvis} avis',
                          style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Montants.affiche(h.prixParNuit),
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('par nuit', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
        ],
      );

  Widget _infos(Hebergement h) {
    final infos = <(IconData, String, String)>[
      (Icons.group_outlined, 'Capacité', '${h.capacite} pers. / chambre'),
      (Icons.meeting_room_outlined, 'Chambres', '${h.nbChambres}'),
      if (h.superficie != null)
        (Icons.square_foot, 'Surface', '${h.superficie!.round()} m²'),
      (Icons.login, 'Arrivée', 'dès ${h.heureArrivee}'),
      (Icons.logout, 'Départ', 'avant ${h.heureDepart}'),
      if (h.telephone != null) (Icons.phone_outlined, 'Téléphone', h.telephone!),
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

  Widget _avis(AvisHebergement a) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Etoiles(nombre: a.note, taille: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.auteur,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text(dateCourte(a.creeLe),
                    style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ],
            ),
            if (a.commentaire != null && a.commentaire!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(a.commentaire!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      );

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

/// Concierge IA : questions sur l'établissement, réponses tirées de sa fiche uniquement.
class _Concierge extends StatefulWidget {
  final Hebergement hebergement;
  final HebergementIaService ia;

  const _Concierge({required this.hebergement, required this.ia});

  @override
  State<_Concierge> createState() => _ConciergeState();
}

class _ConciergeState extends State<_Concierge> {
  final _question = TextEditingController();
  final List<MessageConcierge> _messages = [];
  bool _reflexion = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _envoyer([String? texte]) async {
    final q = (texte ?? _question.text).trim();
    if (q.isEmpty || _reflexion) return;
    _question.clear();
    final historique = List<MessageConcierge>.of(_messages);
    setState(() {
      _messages.add((deClient: true, texte: q));
      _reflexion = true;
    });
    String reponse;
    try {
      reponse = await widget.ia.concierge(q, widget.hebergement, historique: historique);
    } on IaException catch (e) {
      reponse = e.message;
    }
    if (!mounted) return;
    setState(() {
      _messages.add((deClient: false, texte: reponse));
      _reflexion = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Y a-t-il une piscine chauffée ?',
      'À quelle heure puis-je arriver ?',
      'Les animaux sont-ils acceptés ?',
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Concierge · ${widget.hebergement.nom}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!widget.ia.configure)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Concierge indisponible : lancez l\'application avec GEMINI_API_KEY.',
                    style: TextStyle(color: AppColors.orangeText)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_messages.isEmpty && widget.ia.configure)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in suggestions)
                          ActionChip(label: Text(s), onPressed: () => _envoyer(s)),
                      ],
                    ),
                  for (final m in _messages)
                    Align(
                      alignment: m.deClient ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.deClient ? AppColors.teal : AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: m.deClient ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(m.texte,
                            style: TextStyle(
                                color: m.deClient ? AppColors.white : AppColors.navy)),
                      ),
                    ),
                  if (_reflexion)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _question,
                        enabled: widget.ia.configure,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _envoyer(),
                        decoration: decorationUi('Votre question…', icone: Icons.help_outline),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: (widget.ia.configure && !_reflexion) ? () => _envoyer() : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
