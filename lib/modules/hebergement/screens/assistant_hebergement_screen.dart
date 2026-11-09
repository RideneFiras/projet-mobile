import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_ia_service.dart';
import '../hebergement_repository.dart';
import '../models/filtres_hebergement.dart';
import '../models/hebergement.dart';
import 'hebergement_detail_screen.dart';

/// Assistant IA de l'hébergement, en deux onglets :
/// - Recherche : profil (famille, couple…) + description libre -> filtres et
///   3 recommandations ; « Voir tous les résultats » renvoie les filtres à la liste ;
/// - Itinéraire : destination, durée, budget -> programme jour par jour + hébergements.
class AssistantHebergementScreen extends StatefulWidget {
  const AssistantHebergementScreen({super.key});

  @override
  State<AssistantHebergementScreen> createState() => _AssistantHebergementScreenState();
}

class _AssistantHebergementScreenState extends State<AssistantHebergementScreen> {
  final _ia = HebergementIaService();
  final _repo = HebergementRepository();

  // Recherche
  final _demande = TextEditingController();
  ProfilVoyageur? _profil;
  bool _analyse = false;
  FiltresHebergement? _filtres;
  bool _parIa = false;
  List<({Hebergement hebergement, String raison})> _recommandations = const [];

  // Itinéraire
  final _destination = TextEditingController();
  final _jours = TextEditingController(text: '5');
  final _budget = TextEditingController(text: '400');
  bool _generation = false;
  String? _erreurItineraire;
  ({
    List<JourItineraire> jours,
    List<({int hebergementId, String raison})> hebergements,
    String conseil
  })? _itineraire;
  Map<int, Hebergement> _parId = const {};

  @override
  void dispose() {
    for (final c in [_demande, _destination, _jours, _budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _rechercher() async {
    final texte = _demande.text.trim();
    if (texte.isEmpty && _profil == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _analyse = true);
    final analyse = await _ia.analyserDemande(texte);
    var candidats = await _repo.hebergements(ouvertsSeulement: true, filtres: analyse.filtres);
    if (candidats.isEmpty) candidats = await _repo.hebergements(ouvertsSeulement: true);
    final choix = await _ia.recommander(texte, _profil, candidats);
    final parId = {for (final h in candidats) h.id: h};
    if (!mounted) return;
    setState(() {
      _analyse = false;
      _filtres = analyse.filtres;
      _parIa = analyse.parIa;
      _recommandations = [
        for (final c in choix)
          if (parId[c.hebergementId] case final h?) (hebergement: h, raison: c.raison),
      ];
    });
  }

  Future<void> _genererItineraire() async {
    final destination = _destination.text.trim();
    final jours = int.tryParse(_jours.text.trim());
    final budget = Montants.depuisSaisie(_budget.text);
    if (destination.isEmpty || jours == null || jours < 1 || jours > 14 || budget == null) {
      setState(() => _erreurItineraire = 'Destination, durée (1 à 14 jours) et budget requis');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _generation = true;
      _erreurItineraire = null;
    });
    try {
      // Établissements de la destination d'abord, sinon tout le catalogue ouvert.
      var candidats = await _repo.hebergements(ouvertsSeulement: true, recherche: destination);
      if (candidats.isEmpty) candidats = await _repo.hebergements(ouvertsSeulement: true);
      final r = await _ia.itineraire(
          destination: destination, jours: jours, budget: budget, candidats: candidats);
      if (!mounted) return;
      setState(() {
        _itineraire = r;
        _parId = {for (final h in candidats) h.id!: h};
      });
    } on IaException catch (e) {
      if (mounted) setState(() => _erreurItineraire = e.message);
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  void _ouvrir(Hebergement h) => Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => HebergementDetailScreen(hebergementId: h.id!)),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: EcranModule(
        titre: 'Assistant hébergement',
        corps: Column(
          children: [
            if (!_ia.configure)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'IA non configurée (GEMINI_API_KEY) : recherche par mots-clés, '
                  'itinéraire indisponible.',
                  style: TextStyle(color: AppColors.orangeText, fontSize: 12),
                ),
              ),
            const TabBar(
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.orange,
              tabs: [Tab(text: 'Recherche'), Tab(text: 'Itinéraire')],
            ),
            Expanded(child: TabBarView(children: [_ongletRecherche(), _ongletItineraire()])),
          ],
        ),
      ),
    );
  }

  Widget _ongletRecherche() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Vous voyagez…',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in ProfilVoyageur.values)
                ChoiceChip(
                  label: Text(p.libelle),
                  selected: _profil == p,
                  showCheckmark: false,
                  selectedColor: AppColors.teal,
                  backgroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _profil == p ? AppColors.white : AppColors.navy),
                  onSelected: (oui) => setState(() => _profil = oui ? p : null),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ChampTexte(
            controller: _demande,
            label: 'Ex. : « riad calme à Tunis avec petit-déjeuner, 200 DT max »',
            icone: Icons.chat_bubble_outline,
            clavier: TextInputType.multiline,
            lignes: 3,
            capitalisation: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          BoutonPrincipal(
            libelle: _analyse ? 'Analyse en cours…' : 'Trouver où dormir',
            icone: Icons.auto_awesome,
            onPressed: _analyse ? null : _rechercher,
          ),
          if (_filtres != null) ...[
            const SizedBox(height: 20),
            Text(_parIa ? 'Critères compris par l\'IA' : 'Critères détectés (analyse locale)',
                style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _criteres(_filtres!)),
            const SizedBox(height: 16),
            EnteteSection(
              titre: 'Recommandations',
              action: TextButton(
                onPressed: () => Navigator.pop(context, _filtres),
                child: const Text('Voir tous les résultats'),
              ),
            ),
            const SizedBox(height: 8),
            if (_recommandations.isEmpty)
              const Text('Aucun établissement ouvert ne correspond pour le moment.',
                  style: TextStyle(color: AppColors.grey))
            else
              for (final r in _recommandations) ...[
                _carte(r.hebergement, r.raison),
                const SizedBox(height: 10),
              ],
          ],
        ],
      );

  List<Widget> _criteres(FiltresHebergement f) {
    final textes = [
      if (f.type != null) f.type!.libelle,
      if (f.recherche != null) f.recherche!,
      if (f.etoilesMin != null) '${f.etoilesMin} ★ et +',
      if (f.personnes != null) '${f.personnes} voyageurs',
      if (f.prixMax != null) '≤ ${f.prixMax!.toStringAsFixed(0)} DT/nuit',
      for (final e in f.equipements) e.libelle,
    ];
    if (textes.isEmpty) {
      return const [Text('Aucun critère précis', style: TextStyle(color: AppColors.grey))];
    }
    return [for (final t in textes) Pastille(libelle: t, valeur: 'confirmee')];
  }

  Widget _ongletItineraire() {
    final it = _itineraire;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ChampTexte(
          controller: _destination,
          label: 'Destination (ex : Hammamet)',
          icone: Icons.place_outlined,
          capitalisation: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChampTexte(
                controller: _jours,
                label: 'Jours',
                icone: Icons.calendar_today_outlined,
                clavier: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChampTexte(
                controller: _budget,
                label: 'Budget total (DT)',
                icone: Icons.payments_outlined,
                clavier: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_erreurItineraire != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_erreurItineraire!, style: const TextStyle(color: AppColors.danger)),
          ),
        BoutonPrincipal(
          libelle: _generation ? 'Préparation du séjour…' : 'Proposer un séjour',
          icone: Icons.route_outlined,
          onPressed: (_generation || !_ia.configure) ? null : _genererItineraire,
        ),
        if (it != null) ...[
          const SizedBox(height: 20),
          if (it.hebergements.isNotEmpty) ...[
            const EnteteSection(titre: 'Où dormir'),
            const SizedBox(height: 8),
            for (final c in it.hebergements)
              if (_parId[c.hebergementId] case final h?) ...[
                _carte(h, c.raison),
                const SizedBox(height: 10),
              ],
          ],
          const SizedBox(height: 8),
          const EnteteSection(titre: 'Programme'),
          const SizedBox(height: 8),
          for (final (i, j) in it.jours.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CarteModule(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jour ${i + 1} · ${j.titre}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(j.programme, style: const TextStyle(color: AppColors.navy)),
                  ],
                ),
              ),
            ),
          if (it.conseil.isNotEmpty)
            Text('💡 ${it.conseil}', style: const TextStyle(color: AppColors.grey)),
        ],
      ],
    );
  }

  Widget _carte(Hebergement h, String raison) => CarteModule(
        onTap: () => _ouvrir(h),
        child: Row(
          children: [
            Icon(h.type.icone, color: AppColors.teal, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(raison, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                ],
              ),
            ),
            Text('${Montants.affiche(h.prixParNuit)}/nuit',
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
