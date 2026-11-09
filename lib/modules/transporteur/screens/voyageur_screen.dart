import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/travel_field.dart';
import '../../user/role.dart';
import '../../user/user_repository.dart';
import '../models/mise_en_relation.dart';
import '../models/reservation_transport.dart';
import '../transport_format.dart';
import '../transport_ia.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Espace voyageur (UI Kit : « Transport »).
/// Deux onglets : les propositions reçues (à accepter ou refuser) et la recherche
/// de trajets, avec un résumé rédigé par l'assistant IA pour chaque trajet.
class VoyageurScreen extends StatefulWidget {
  const VoyageurScreen({super.key});

  @override
  State<VoyageurScreen> createState() => _VoyageurScreenState();
}

class _VoyageurScreenState extends State<VoyageurScreen> {
  bool _charge = false;
  int? _voyageurId;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await UserRepository().utilisateurConnecte();
    if (!mounted) return;
    setState(() {
      _charge = true;
      _voyageurId = u?.role == Role.traveller ? u?.id : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_charge) {
      return const EcranTransport(
          titre: 'Transport',
          child: Center(child: CircularProgressIndicator()));
    }
    final id = _voyageurId;
    if (id == null) {
      return const EcranTransport(
        titre: 'Transport',
        child: EtatVide(
            icone: Icons.flight_outlined,
            message: 'Cet écran est réservé aux comptes voyageur.'),
      );
    }
    return DefaultTabController(
      length: 2,
      child: EcranTransport(
        titre: 'Transport',
        bottom: const TabBar(
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.teal,
          tabs: [
            Tab(text: 'Propositions'),
            Tab(text: 'Trouver un trajet'),
          ],
        ),
        child: TabBarView(
          children: [
            _Propositions(voyageurId: id),
            const _RechercheTrajets(),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Propositions reçues
// ----------------------------------------------------------------------

class _Propositions extends StatefulWidget {
  final int voyageurId;

  const _Propositions({required this.voyageurId});

  @override
  State<_Propositions> createState() => _PropositionsState();
}

class _PropositionsState extends State<_Propositions> {
  final _repo = TransportRepository();
  late Future<List<MiseEnRelation>> _liste =
      _repo.relationsDuVoyageur(widget.voyageurId);

  void _recharger() =>
      setState(() => _liste = _repo.relationsDuVoyageur(widget.voyageurId));

  Future<void> _repondre(MiseEnRelation r, {required bool accepter}) async {
    if (r.id == null) return;
    final erreur = await _repo.repondreProposition(
      relationId: r.id!,
      voyageurId: widget.voyageurId,
      accepter: accepter,
    );
    if (!mounted) return;
    montrerMessage(context,
        erreur ?? (accepter ? 'Commande acceptée : coordonnées partagées' : 'Proposition refusée'));
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _recharger(),
      child: FutureBuilder<List<MiseEnRelation>>(
        future: _liste,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <MiseEnRelation>[];
          if (items.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EtatVide(
                  icone: Icons.inbox_outlined,
                  message:
                      'Aucune proposition pour le moment.\nLes transporteurs vous proposeront des commandes sur votre trajet.'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = items[i];
              return CarteTransport(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.trajet ?? 'Commande',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        BadgeStatut(
                            libelle: r.statut.libelle, valeur: r.statut.valeur),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Client : ${r.nomClient ?? '—'}'
                      '${r.budget == null ? '' : ' · Budget ${TransportFormat.prix(r.budget!)}'}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 14),
                    ),
                    if (r.acceptee) ...[
                      const SizedBox(height: 12),
                      BlocContact(
                          titre: 'CLIENT',
                          nom: r.nomClient,
                          contact: r.contactClient),
                    ],
                    if (r.statut == StatutRelation.proposee) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _repondre(r, accepter: false),
                              child: const Text('Refuser'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: AppColors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _repondre(r, accepter: true),
                              child: const Text('Accepter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Recherche de trajets
// ----------------------------------------------------------------------

class _RechercheTrajets extends StatefulWidget {
  const _RechercheTrajets();

  @override
  State<_RechercheTrajets> createState() => _RechercheTrajetsState();
}

class _RechercheTrajetsState extends State<_RechercheTrajets> {
  final _repo = TransportRepository();
  final _depart = TextEditingController();
  final _arrivee = TextEditingController();
  DateTime? _date;
  Future<List<ReservationTransport>>? _resultats;

  @override
  void dispose() {
    _depart.dispose();
    _arrivee.dispose();
    super.dispose();
  }

  void _chercher() {
    FocusScope.of(context).unfocus();
    setState(() => _resultats = _repo.trajets(
          depart: _depart.text,
          arrivee: _arrivee.text,
          date: _date,
        ));
  }

  Future<void> _afficherResume(ReservationTransport t) async {
    final futur = TransportIa.resumerTrajet(t);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résumé du trajet'),
        content: FutureBuilder<({String texte, SourceIa source})>(
          future: futur,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()));
            }
            final r = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.texte, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                BandeauSource(source: r.source),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TravelField(
          label: 'Départ',
          hint: 'Toutes les villes',
          icone: Icons.trip_origin,
          controller: _depart,
        ),
        const SizedBox(height: 12),
        TravelField(
          label: 'Arrivée',
          hint: 'Toutes les villes',
          icone: Icons.flag_outlined,
          controller: _arrivee,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        ChampDate(
          label: 'Date (facultatif)',
          valeur: _date,
          onChoisie: (d) => setState(() => _date = d),
        ),
        if (_date != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _date = null),
              child: const Text('Effacer la date'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: _chercher,
            icon: const Icon(Icons.search),
            label: const Text('Rechercher',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 20),
        if (_resultats == null)
          const EtatVide(
              icone: Icons.search,
              message: 'Indiquez un départ, une arrivée ou une date.')
        else
          FutureBuilder<List<ReservationTransport>>(
            future: _resultats,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data ?? const <ReservationTransport>[];
              if (items.isEmpty) {
                return const EtatVide(
                    icone: Icons.alt_route,
                    message: 'Aucun trajet trouvé pour ces critères.');
              }
              return Column(
                children: [
                  for (final t in items) ...[
                    CarteTransport(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: LigneTrajet(
                                      depart: t.depart, arrivee: t.arrivee)),
                              BadgeStatut(
                                  libelle: t.statut.libelle,
                                  valeur: t.statut.valeur),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${dateCourte(t.dateDepart)} · ${TransportFormat.prix(t.prix)}'
                            '${t.nomTransporteur == null ? '' : ' · ${t.nomTransporteur}'}',
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 14),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _afficherResume(t),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Résumé'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
