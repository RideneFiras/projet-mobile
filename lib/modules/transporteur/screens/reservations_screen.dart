import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../user/role.dart';
import '../../user/user_repository.dart';
import '../models/reservation_transport.dart';
import '../models/transporteur.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';
import 'trajet_form_screen.dart';
import 'transporteur_form_screen.dart';

/// Gestion des réservations de transport (UI Kit : « Réservations »).
/// Deux onglets : les trajets proposés et les fiches des transporteurs.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _repo = TransportRepository();
  bool _charge = false;
  bool _autorise = false;

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
      _autorise = u?.role == Role.transporter;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_charge) {
      return const EcranTransport(
          titre: 'Réservations',
          child: Center(child: CircularProgressIndicator()));
    }
    if (!_autorise) {
      return const EcranTransport(
        titre: 'Réservations',
        child: EtatVide(
            icone: Icons.event_available_outlined,
            message: 'Cet écran est réservé aux comptes transporteur.'),
      );
    }
    return DefaultTabController(
      length: 2,
      child: EcranTransport(
        titre: 'Réservations',
        bottom: const TabBar(
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.teal,
          tabs: [
            Tab(text: 'Trajets'),
            Tab(text: 'Transporteurs'),
          ],
        ),
        child: TabBarView(
          children: [
            _ListeTrajets(repo: _repo),
            _ListeTransporteurs(repo: _repo),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Ajouter » en haut de chaque liste.
class _EnTeteListe extends StatelessWidget {
  final String titre;
  final VoidCallback onAjouter;

  const _EnTeteListe({required this.titre, required this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(titre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: AppColors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: onAjouter,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _ListeTrajets extends StatefulWidget {
  final TransportRepository repo;

  const _ListeTrajets({required this.repo});

  @override
  State<_ListeTrajets> createState() => _ListeTrajetsState();
}

class _ListeTrajetsState extends State<_ListeTrajets> {
  late Future<List<ReservationTransport>> _liste = widget.repo.trajets();

  void _recharger() => setState(() => _liste = widget.repo.trajets());

  Future<void> _ouvrirFormulaire([ReservationTransport? trajet]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TrajetFormScreen(trajet: trajet)));
    _recharger();
  }

  Future<void> _supprimer(ReservationTransport t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce trajet ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || t.id == null) return;
    await widget.repo.supprimerTrajet(t.id!);
    if (!mounted) return;
    montrerMessage(context, 'Trajet supprimé');
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _recharger(),
      child: FutureBuilder<List<ReservationTransport>>(
        future: _liste,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <ReservationTransport>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EnTeteListe(
                  titre: '${items.length} trajet(s)',
                  onAjouter: () => _ouvrirFormulaire()),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EtatVide(
                    icone: Icons.alt_route,
                    message: 'Aucun trajet. Ajoutez le premier trajet proposé.')
              else
                for (final t in items) ...[
                  CarteTransport(
                    onTap: () => _ouvrirFormulaire(t),
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
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger),
                            onPressed: () => _supprimer(t),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Supprimer'),
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
    );
  }
}

class _ListeTransporteurs extends StatefulWidget {
  final TransportRepository repo;

  const _ListeTransporteurs({required this.repo});

  @override
  State<_ListeTransporteurs> createState() => _ListeTransporteursState();
}

class _ListeTransporteursState extends State<_ListeTransporteurs> {
  late Future<List<Transporteur>> _liste = widget.repo.transporteurs();

  void _recharger() => setState(() => _liste = widget.repo.transporteurs());

  Future<void> _ouvrirFormulaire([Transporteur? fiche]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransporteurFormScreen(transporteur: fiche)));
    _recharger();
  }

  Future<void> _supprimer(Transporteur t) async {
    if (t.id == null) return;
    await widget.repo.supprimerTransporteur(t.id!);
    if (!mounted) return;
    montrerMessage(context,
        'Transporteur supprimé : ses trajets restent, sans transporteur associé');
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _recharger(),
      child: FutureBuilder<List<Transporteur>>(
        future: _liste,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <Transporteur>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EnTeteListe(
                  titre: '${items.length} transporteur(s)',
                  onAjouter: () => _ouvrirFormulaire()),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EtatVide(
                    icone: Icons.local_shipping_outlined,
                    message: 'Aucun transporteur enregistré.')
              else
                for (final t in items) ...[
                  CarteTransport(
                    onTap: () => _ouvrirFormulaire(t),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.tealLight,
                          child: Icon(Icons.local_shipping_outlined,
                              color: AppColors.teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.nom,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('${t.type} · ${t.contact}',
                                  style: const TextStyle(
                                      color: AppColors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          color: AppColors.danger,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _supprimer(t),
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
    );
  }
}
