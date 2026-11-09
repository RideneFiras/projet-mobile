import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/galerie_photos.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_repository.dart';
import '../models/filtres_hebergement.dart';
import '../models/hebergement.dart';
import 'assistant_hebergement_screen.dart';
import 'carte_hebergements_screen.dart';
import 'comparateur_screen.dart';
import 'etoiles.dart';
import 'filtres_hebergement_sheet.dart';
import 'hebergement_detail_screen.dart';
import 'hebergement_form_screen.dart';

/// Liste des établissements, en deux modes :
/// - [gestion] = true (administrateur) : tout le catalogue, ajout et suppression ;
/// - [gestion] = false (voyageur) : établissements ouverts uniquement.
/// Recherche, types, équipements, filtres avancés, tri, carte, assistant IA et
/// comparateur (appui long sur 2 ou 3 établissements).
class HebergementsTab extends StatefulWidget {
  final bool gestion;

  const HebergementsTab({super.key, this.gestion = false});

  @override
  State<HebergementsTab> createState() => _HebergementsTabState();
}

class _HebergementsTabState extends State<HebergementsTab> {
  final _repo = HebergementRepository();
  final _recherche = TextEditingController();
  FiltresHebergement _filtres = const FiltresHebergement();
  TriHebergement _tri = TriHebergement.nom;
  final Set<int> _aComparer = {};
  late Future<List<Hebergement>> _futur;

  /// Équipements proposés en filtre rapide.
  static const _filtresRapides = [
    Equipement.wifi,
    Equipement.piscine,
    Equipement.parking,
    Equipement.petitDejeuner,
    Equipement.plage,
  ];

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<List<Hebergement>> _charger() => _repo.hebergements(
        filtres: _filtres.copyWith(recherche: _recherche.text),
        ouvertsSeulement: !widget.gestion,
        tri: _tri,
      );

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _ouvrirFiltres() async {
    final f = await ouvrirFiltresHebergement(context, _filtres);
    if (f == null || !mounted) return;
    _filtres = f;
    if (f.aPositionRef && _tri == TriHebergement.nom) _tri = TriHebergement.distance;
    await _recharger();
  }

  Future<void> _ouvrirAssistant() async {
    final f = await Navigator.push<FiltresHebergement>(
      context,
      MaterialPageRoute(builder: (_) => const AssistantHebergementScreen()),
    );
    if (f == null || !mounted) return;
    _filtres = f;
    _recherche.text = f.recherche ?? '';
    await _recharger();
  }

  Future<void> _ouvrirCarte() async {
    final liste = await _futur;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
          builder: (_) => CarteHebergementsScreen(hebergements: liste, gestion: widget.gestion)),
    );
  }

  Future<void> _comparer(List<Hebergement> liste) async {
    final choisis = [for (final h in liste) if (_aComparer.contains(h.id)) h];
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ComparateurScreen(hebergements: choisis)),
    );
  }

  void _basculerComparaison(Hebergement h) {
    setState(() {
      if (!_aComparer.remove(h.id)) {
        if (_aComparer.length >= 3) {
          afficherMessage(context, '3 établissements au maximum', erreur: true);
          return;
        }
        _aComparer.add(h.id!);
      }
    });
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const HebergementFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _ouvrir(Hebergement h) async {
    if (_aComparer.isNotEmpty) {
      _basculerComparaison(h);
      return;
    }
    final change = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HebergementDetailScreen(
          hebergementId: h.id!,
          gestion: widget.gestion,
          arrivee: _filtres.aDates ? _filtres.arrivee : null,
          depart: _filtres.aDates ? _filtres.depart : null,
        ),
      ),
    );
    if (change == true && mounted) await _recharger();
  }

  Future<void> _supprimer(Hebergement h) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ${h.nom} ?',
      message: 'Les séjours réservés dans cet établissement seront supprimés aussi.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerHebergement(h.id!);
    if (!mounted) return;
    afficherMessage(context, 'Établissement supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final nbFiltres = _filtres.nombreActifs;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _recharger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _recherche,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _recharger(),
                      decoration: decorationUi('Nom, adresse ou ville', icone: Icons.search),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<TriHebergement>(
                    tooltip: 'Trier',
                    icon: const Icon(Icons.sort, color: AppColors.navy),
                    initialValue: _tri,
                    onSelected: (t) {
                      if (t == TriHebergement.distance && !_filtres.aPositionRef) {
                        afficherMessage(context,
                            'Indiquez d\'abord votre position dans les filtres.',
                            erreur: true);
                        return;
                      }
                      _tri = t;
                      _recharger();
                    },
                    itemBuilder: (_) => [
                      for (final t in TriHebergement.values)
                        PopupMenuItem(value: t, child: Text(t.libelle)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _puces(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _ouvrirFiltres,
                    icon: Badge(
                      isLabelVisible: nbFiltres > 0,
                      label: Text('$nbFiltres'),
                      child: const Icon(Icons.tune),
                    ),
                    label: Text('Filtres · ${_tri.libelle}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _ouvrirCarte,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Carte'),
                  ),
                  if (!widget.gestion)
                    FilledButton.tonalIcon(
                      onPressed: _ouvrirAssistant,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Assistant IA'),
                    ),
                ],
              ),
              if (!widget.gestion)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Astuce : appui long sur une carte pour comparer.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 16),
              FutureBuilder<List<Hebergement>>(
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
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _liste(snap.data!);
                },
              ),
            ],
          ),
        ),
        if (_aComparer.length >= 2)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: FutureBuilder<List<Hebergement>>(
              future: _futur,
              builder: (context, snap) => FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: snap.hasData ? () => _comparer(snap.data!) : null,
                icon: const Icon(Icons.compare_arrows),
                label: Text('Comparer (${_aComparer.length})'),
              ),
            ),
          ),
      ],
    );
  }

  /// Ligne 1 : types (choix unique). Ligne 2 : équipements (tous requis).
  Widget _puces() {
    Widget puce({
      required String libelle,
      required IconData icone,
      required bool actif,
      required VoidCallback onTap,
    }) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            avatar: Icon(icone, size: 18, color: actif ? AppColors.white : AppColors.teal),
            label: Text(libelle),
            selected: actif,
            showCheckmark: false,
            selectedColor: AppColors.teal,
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: actif ? AppColors.white : AppColors.navy),
            onSelected: (_) => onTap(),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              puce(
                libelle: 'Tous',
                icone: Icons.apps,
                actif: _filtres.type == null,
                onTap: () {
                  _filtres = _filtres.copyWith(effacerType: true);
                  _recharger();
                },
              ),
              for (final t in TypeHebergement.values)
                puce(
                  libelle: t.libelle,
                  icone: t.icone,
                  actif: _filtres.type == t,
                  onTap: () {
                    _filtres = _filtres.copyWith(type: t);
                    _recharger();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in _filtresRapides)
                puce(
                  libelle: e.libelle,
                  icone: e.icone,
                  actif: _filtres.equipements.contains(e),
                  onTap: () {
                    final s = {..._filtres.equipements};
                    if (!s.remove(e)) s.add(e);
                    _filtres = _filtres.copyWith(equipements: s);
                    _recharger();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _liste(List<Hebergement> liste) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnteteSection(
          titre: widget.gestion
              ? 'Établissements (${liste.length})'
              : 'Où dormir (${liste.length})',
          action: widget.gestion
              ? TextButton.icon(
                  onPressed: _ajouter,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                )
              : null,
        ),
        const SizedBox(height: 14),
        if (liste.isEmpty)
          (widget.gestion
              ? EtatVideModule(
                  icone: Icons.bed_outlined,
                  titre: 'Aucun établissement',
                  message: 'Ajoutez les hôtels, riads et logements proposés.',
                  libelleAction: 'Ajouter un établissement',
                  onAction: _ajouter,
                )
              : const EtatVideModule(
                  icone: Icons.bed_outlined,
                  titre: 'Aucun résultat',
                  message: 'Modifiez la recherche, retirez des filtres ou demandez à l\'assistant.',
                ))
        else
          GrilleAdaptative(
            largeurMin: 320,
            enfants: [for (final h in liste) _carte(h)],
          ),
      ],
    );
  }

  Widget _carte(Hebergement h) {
    final selection = _aComparer.contains(h.id);
    final distance = (_filtres.aPositionRef && h.aPosition)
        ? distanceKm(_filtres.latitudeRef!, _filtres.longitudeRef!, h.latitude!, h.longitude!)
        : null;
    return GestureDetector(
      onLongPress: widget.gestion ? null : () => _basculerComparaison(h),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: selection ? Border.all(color: AppColors.orange, width: 3) : null,
        ),
        child: CarteModule(
          accent: couleursStatut(h.statut.valeur).$2,
          onTap: () => _ouvrir(h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  PhotoModule(
                    source: h.photoPrincipale,
                    iconeParDefaut: h.type.icone,
                    hauteur: 150,
                    largeur: double.infinity,
                  ),
                  if (h.nbAvis > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppColors.orange),
                            Text(' ${h.noteMoyenne.toStringAsFixed(1)} (${h.nbAvis})',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  if (selection)
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.orange,
                        child: Icon(Icons.check, size: 18, color: AppColors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(h.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  if (h.etoiles != null) Etoiles(nombre: h.etoiles!),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(h.type.icone, size: 14, color: AppColors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        [
                          h.type.libelle,
                          if (distance != null) distanceLisible(distance),
                          h.adresseComplete,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  ),
                ],
              ),
              if (h.equipements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final e in h.equipements.take(5))
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Tooltip(
                          message: e.libelle,
                          child: Icon(e.icone, size: 18, color: AppColors.teal),
                        ),
                      ),
                    if (h.equipements.length > 5)
                      Text('+${h.equipements.length - 5}',
                          style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!h.ouvert || widget.gestion)
                    Pastille(libelle: h.statut.libelle, valeur: h.statut.valeur),
                  if (h.nbReservations > 0) ...[
                    const SizedBox(width: 6),
                    Text('${h.nbReservations} séjour${h.nbReservations > 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                  const Spacer(),
                  Text('${Montants.affiche(h.prixParNuit)} / nuit',
                      style: const TextStyle(
                          color: AppColors.teal, fontSize: 15, fontWeight: FontWeight.w800)),
                  if (widget.gestion)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () => _supprimer(h),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
