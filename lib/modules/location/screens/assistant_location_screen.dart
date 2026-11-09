import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_ia_service.dart';
import '../location_repository.dart';
import '../models/filtres_vehicule.dart';
import '../models/vehicule.dart';
import 'vehicule_detail_screen.dart';

/// Assistant IA de la location, en deux onglets :
/// - Recherche : description libre -> filtres + 3 recommandations argumentées ;
///   « Voir tous les résultats » renvoie les filtres à la liste ;
/// - Questions : chatbot qui répond à partir de la flotte réelle.
class AssistantLocationScreen extends StatefulWidget {
  const AssistantLocationScreen({super.key});

  @override
  State<AssistantLocationScreen> createState() => _AssistantLocationScreenState();
}

class _AssistantLocationScreenState extends State<AssistantLocationScreen> {
  final _ia = LocationIaService();
  final _repo = LocationRepository();
  final _demande = TextEditingController();
  final _question = TextEditingController();
  final _defilement = ScrollController();

  bool _analyse = false;
  FiltresVehicule? _filtres;
  bool _parIa = false;
  List<({Vehicule vehicule, String raison})> _recommandations = const [];

  final List<MessageAssistant> _messages = [];
  bool _reflexion = false;

  @override
  void dispose() {
    _demande.dispose();
    _question.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _rechercher() async {
    final texte = _demande.text.trim();
    if (texte.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _analyse = true);
    final analyse = await _ia.analyserDemande(texte);
    var candidats = await _repo.vehicules(reservablesSeulement: true, filtres: analyse.filtres);
    if (candidats.isEmpty) candidats = await _repo.vehicules(reservablesSeulement: true);
    final choix = await _ia.recommander(texte, candidats);
    final parId = {for (final v in candidats) v.id: v};
    if (!mounted) return;
    setState(() {
      _analyse = false;
      _filtres = analyse.filtres;
      _parIa = analyse.parIa;
      _recommandations = [
        for (final c in choix)
          if (parId[c.vehiculeId] case final v?) (vehicule: v, raison: c.raison),
      ];
    });
  }

  Future<void> _envoyer() async {
    final q = _question.text.trim();
    if (q.isEmpty || _reflexion) return;
    _question.clear();
    setState(() {
      _messages.add((deClient: true, texte: q));
      _reflexion = true;
    });
    _defiler();
    String reponse;
    try {
      final flotte = await _repo.vehicules(reservablesSeulement: true);
      reponse = await _ia.repondre(q, flotte,
          historique: _messages.sublist(0, _messages.length - 1));
    } on IaException catch (e) {
      reponse = e.message;
    }
    if (!mounted) return;
    setState(() {
      _messages.add((deClient: false, texte: reponse));
      _reflexion = false;
    });
    _defiler();
  }

  void _defiler() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_defilement.hasClients) {
          _defilement.animateTo(_defilement.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: EcranModule(
        titre: 'Assistant location',
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
                  'IA non configurée (GEMINI_API_KEY) : la recherche utilise une analyse '
                  'locale par mots-clés, les questions sont indisponibles.',
                  style: TextStyle(color: AppColors.orangeText, fontSize: 12),
                ),
              ),
            const TabBar(
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.orange,
              tabs: [Tab(text: 'Recherche'), Tab(text: 'Questions')],
            ),
            Expanded(child: TabBarView(children: [_ongletRecherche(), _ongletQuestions()])),
          ],
        ),
      ),
    );
  }

  Widget _ongletRecherche() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Décrivez ce que vous cherchez',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Ex. : « voiture familiale électrique, 80 DT par jour maximum »',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          ChampTexte(
            controller: _demande,
            label: 'Votre besoin',
            icone: Icons.chat_bubble_outline,
            clavier: TextInputType.multiline,
            lignes: 3,
            capitalisation: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          BoutonPrincipal(
            libelle: _analyse ? 'Analyse en cours…' : 'Trouver mon véhicule',
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
              const Text('Aucun véhicule disponible ne correspond pour le moment.',
                  style: TextStyle(color: AppColors.grey))
            else
              for (final r in _recommandations) ...[
                CarteModule(
                  onTap: () => Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => VehiculeDetailScreen(vehiculeId: r.vehicule.id!)),
                  ),
                  child: Row(
                    children: [
                      Icon(r.vehicule.type.icone, color: AppColors.teal, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.vehicule.nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            Text(r.raison,
                                style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text('${Montants.affiche(r.vehicule.prixParJour)}/j',
                          style: const TextStyle(
                              color: AppColors.teal, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      );

  List<Widget> _criteres(FiltresVehicule f) {
    final textes = [
      if (f.type != null) f.type!.libelle,
      if (f.carburant != null) f.carburant!.libelle,
      if (f.boite != null) 'Boîte ${f.boite!.libelle.toLowerCase()}',
      if (f.placesMin != null) '${f.placesMin}+ places',
      if (f.prixMax != null) '≤ ${f.prixMax!.toStringAsFixed(0)} DT/j',
      if (f.anneeMin != null) 'Depuis ${f.anneeMin}',
      if (f.tri != TriVehicule.nom) f.tri.libelle,
    ];
    if (textes.isEmpty) {
      return const [Text('Aucun critère précis', style: TextStyle(color: AppColors.grey))];
    }
    return [for (final t in textes) Pastille(libelle: t, valeur: 'confirmee')];
  }

  Widget _ongletQuestions() => Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EtatVideModule(
                    icone: Icons.forum_outlined,
                    titre: 'Posez votre question',
                    message: 'Ex. : « Quelle est la différence entre vos motos ? »',
                  )
                : ListView.builder(
                    controller: _defilement,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_reflexion ? 1 : 0),
                    itemBuilder: (_, i) => i == _messages.length
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          )
                        : _bulle(_messages[i]),
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
                      enabled: _ia.configure,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _envoyer(),
                      decoration: decorationUi('Votre question…', icone: Icons.help_outline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: (_ia.configure && !_reflexion) ? _envoyer : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _bulle(MessageAssistant m) => Align(
        alignment: m.deClient ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: m.deClient ? AppColors.teal : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: m.deClient ? null : Border.all(color: AppColors.border),
          ),
          child: Text(m.texte,
              style: TextStyle(color: m.deClient ? AppColors.white : AppColors.navy)),
        ),
      );
}
