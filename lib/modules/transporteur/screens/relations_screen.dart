import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../user/role.dart';
import '../../user/user_repository.dart';
import '../models/mise_en_relation.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Suivi des propositions envoyées par le transporteur (UI Kit : « Mises en relation »).
/// Les coordonnées du voyageur ne s'affichent qu'après son acceptation.
class RelationsScreen extends StatefulWidget {
  const RelationsScreen({super.key});

  @override
  State<RelationsScreen> createState() => _RelationsScreenState();
}

class _RelationsScreenState extends State<RelationsScreen> {
  final _repo = TransportRepository();
  bool _charge = false;
  bool _autorise = false;
  Future<List<MiseEnRelation>>? _liste;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await UserRepository().utilisateurConnecte();
    if (!mounted) return;
    final id = u?.id;
    final autorise = u?.role == Role.transporter && id != null;
    setState(() {
      _charge = true;
      _autorise = autorise;
      _liste = autorise ? _repo.relationsDuTransporteur(id!) : null;
    });
  }

  Future<void> _recharger() async {
    final u = await UserRepository().utilisateurConnecte();
    final id = u?.id;
    if (!mounted || id == null) return;
    setState(() => _liste = _repo.relationsDuTransporteur(id));
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(titre: 'Mises en relation', child: _corps());
  }

  Widget _corps() {
    if (!_charge) return const Center(child: CircularProgressIndicator());
    final liste = _liste;
    if (!_autorise || liste == null) {
      return const EtatVide(
          icone: Icons.swap_horiz,
          message: 'Cet écran est réservé aux comptes transporteur.');
    }
    return FutureBuilder<List<MiseEnRelation>>(
      future: liste,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <MiseEnRelation>[];
        return RefreshIndicator(
          onRefresh: _recharger,
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EtatVide(
                      icone: Icons.swap_horiz,
                      message:
                          'Aucune mise en relation.\nProposez un voyageur depuis « Commandes ouvertes ».'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CarteRelation(relation: items[i]),
                ),
        );
      },
    );
  }
}

class _CarteRelation extends StatelessWidget {
  final MiseEnRelation relation;

  const _CarteRelation({required this.relation});

  @override
  Widget build(BuildContext context) {
    final r = relation;
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
              BadgeStatut(libelle: r.statut.libelle, valeur: r.statut.valeur),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Voyageur : ${r.nomVoyageur ?? '—'}'
            '${r.budget == null ? '' : ' · Budget ${TransportFormat.prix(r.budget!)}'}',
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
          ),
          if (r.nomTransporteur != null) ...[
            const SizedBox(height: 4),
            Text('Transporteur : ${r.nomTransporteur}',
                style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          BlocContact(
              titre: 'VOYAGEUR',
              nom: r.nomVoyageur,
              contact: r.contactVoyageur),
          if (r.acceptee) ...[
            const SizedBox(height: 8),
            BlocContact(
                titre: 'CLIENT',
                nom: r.nomClient,
                contact: r.contactClient),
          ],
        ],
      ),
    );
  }
}
