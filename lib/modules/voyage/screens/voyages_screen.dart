import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/voyage.dart';
import '../voyage_repository.dart';
import 'voyage_detail_screen.dart';
import 'voyage_form_screen.dart';

/// Liste « Mes voyages » : lecture, ajout, modification et suppression.
class VoyagesScreen extends StatefulWidget {
  const VoyagesScreen({super.key});

  @override
  State<VoyagesScreen> createState() => _VoyagesScreenState();
}

class _VoyagesScreenState extends State<VoyagesScreen> {
  final _repo = VoyageRepository();
  late Future<List<Voyage>> _futur;
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';
  StatutVoyage? _filtre;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  /// Filtre la liste (mot-clé dans titre/destination + statut affiché).
  List<Voyage> _filtrer(List<Voyage> tous) {
    final q = _recherche.trim().toLowerCase();
    return tous.where((v) {
      final okTexte = q.isEmpty ||
          v.titre.toLowerCase().contains(q) ||
          v.destination.toLowerCase().contains(q);
      final okStatut = _filtre == null || v.statutEffectif == _filtre;
      return okTexte && okStatut;
    }).toList();
  }

  Future<List<Voyage>> _charger() async {
    final id = await SessionService.instance.utilisateurId();
    if (id == null) return const [];
    return _repo.voyagesDe(id);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _nouveau() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoyageFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  /// Ouvre la fiche du voyage ; on recharge au retour (modification, annulation...).
  Future<void> _ouvrir(Voyage v) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VoyageDetailScreen(voyage: v)),
    );
    if (mounted) await _recharger();
  }

  Future<void> _supprimer(Voyage v) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce voyage ?',
      message: 'Les réservations de location et d\'hébergement liées à '
          '« ${v.titre} » seront aussi supprimées.',
    );
    if (!ok || !mounted) return;
    final id = await SessionService.instance.utilisateurId();
    if (id == null || !mounted) return;
    await _repo.supprimer(v.id!, id);
    if (!mounted) return;
    afficherMessage(context, 'Voyage supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Mes voyages',
      boutonFlottant: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau voyage',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _nouveau,
      ),
      corps: FutureBuilder<List<Voyage>>(
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
          final voyages = snap.data!;
          final visibles = _filtrer(voyages);
          final budget = voyages.fold<double>(0, (somme, v) => somme + v.budget);
          return RefreshIndicator(
            onRefresh: _recharger,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                EnTeteModule(
                  titre: 'Mes voyages',
                  sousTitre: 'Planifiez vos trajets, puis réservez location et hébergement.',
                  icone: Icons.luggage_outlined,
                  indicateurs: [
                    IndicateurEnTete(
                        valeur: '${voyages.length}',
                        libelle: 'voyages',
                        icone: Icons.luggage_outlined),
                    IndicateurEnTete(
                        valeur: Montants.affiche(budget),
                        libelle: 'budget total',
                        icone: Icons.payments_outlined),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (voyages.isNotEmpty) ...[
                        TextField(
                          controller: _rechercheCtrl,
                          decoration: decorationUi(
                              'Rechercher (titre ou destination)',
                              icone: Icons.search),
                          onChanged: (t) => setState(() => _recherche = t),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('Tous'),
                                  selected: _filtre == null,
                                  onSelected: (_) =>
                                      setState(() => _filtre = null),
                                ),
                              ),
                              for (final s in StatutVoyage.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(s.libelle),
                                    selected: _filtre == s,
                                    onSelected: (_) =>
                                        setState(() => _filtre = s),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (voyages.isEmpty)
                        EtatVideModule(
                          icone: Icons.luggage_outlined,
                          titre: 'Aucun voyage pour le moment',
                          message: 'Créez votre premier voyage pour commencer.',
                          libelleAction: 'Créer un voyage',
                          onAction: _nouveau,
                        )
                      else if (visibles.isEmpty)
                        const EtatVideModule(
                          icone: Icons.search_off,
                          titre: 'Aucun résultat',
                          message: 'Essayez un autre mot-clé ou un autre statut.',
                        )
                      else
                        Column(children: [for (final v in visibles) _carte(v)]),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _carte(Voyage v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CarteModule(
        accent: couleursStatut(v.statutEffectif.valeur).$2,
        onTap: () => _ouvrir(v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(v.titre,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                Pastille(
                    libelle: v.statutEffectif.libelle,
                    valeur: v.statutEffectif.valeur),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: AppColors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(v.destination,
                      style: const TextStyle(color: AppColors.grey, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 16, color: AppColors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${periode(v.dateDebut, v.dateFin)}  ·  ${v.duree} j',
                    style: const TextStyle(color: AppColors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(Montants.affiche(v.budget),
                    style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
