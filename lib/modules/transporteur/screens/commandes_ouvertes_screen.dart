import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/travel_button.dart';
import '../../user/role.dart';
import '../../user/user_repository.dart';
import '../models/commande_transport.dart';
import '../models/transporteur.dart';
import '../transport_format.dart';
import '../transport_ia.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Commandes ouvertes, vues par les transporteurs (UI Kit : « Commandes ouvertes »).
/// Un transporteur choisit un voyageur sur le même trajet : l'assistant classe
/// les voyageurs, puis la proposition est envoyée au voyageur qui accepte ou refuse.
class CommandesOuvertesScreen extends StatefulWidget {
  const CommandesOuvertesScreen({super.key});

  @override
  State<CommandesOuvertesScreen> createState() =>
      _CommandesOuvertesScreenState();
}

class _CommandesOuvertesScreenState extends State<CommandesOuvertesScreen> {
  final _repo = TransportRepository();
  int? _auteurId;
  bool _charge = false;
  bool _autorise = false;
  Future<List<CommandeTransport>>? _liste;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await UserRepository().utilisateurConnecte();
    if (!mounted) return;
    final autorise = u?.role == Role.transporter && u?.id != null;
    setState(() {
      _charge = true;
      _autorise = autorise;
      _auteurId = autorise ? u!.id : null;
      _liste = autorise ? _repo.commandesOuvertes() : null;
    });
  }

  void _recharger() {
    if (!_autorise) return;
    setState(() => _liste = _repo.commandesOuvertes());
  }

  Future<void> _mettreEnRelation(CommandeTransport c) async {
    final auteur = _auteurId;
    if (auteur == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => _FeuilleRelation(commande: c, auteurId: auteur),
    );
    if (ok == true && mounted) {
      montrerMessage(context, 'Proposition envoyée au voyageur');
      _recharger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(titre: 'Commandes ouvertes', child: _corps());
  }

  Widget _corps() {
    if (!_charge) return const Center(child: CircularProgressIndicator());
    final liste = _liste;
    if (!_autorise || liste == null) {
      return const EtatVide(
          icone: Icons.local_shipping_outlined,
          message: 'Cet écran est réservé aux comptes transporteur.');
    }
    return FutureBuilder<List<CommandeTransport>>(
      future: liste,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <CommandeTransport>[];
        return RefreshIndicator(
          onRefresh: () async => _recharger(),
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EtatVide(
                      icone: Icons.inbox_outlined,
                      message: 'Aucune commande ouverte pour le moment.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return CarteTransport(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LigneTrajet(depart: c.depart, arrivee: c.arrivee),
                          const SizedBox(height: 6),
                          Text(
                            '${dateCourte(c.dateSouhaitee)} · Budget ${TransportFormat.prix(c.budget)}',
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 14),
                          ),
                          if (c.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(c.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14)),
                          ],
                          const SizedBox(height: 12),
                          TravelButton(
                            texte: 'Mettre en relation',
                            onPressed: () => _mettreEnRelation(c),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Feuille basse : classement des voyageurs, choix d'un voyageur et d'un
/// transporteur (facultatif), puis envoi de la proposition.
class _FeuilleRelation extends StatefulWidget {
  final CommandeTransport commande;
  final int auteurId;

  const _FeuilleRelation({required this.commande, required this.auteurId});

  @override
  State<_FeuilleRelation> createState() => _FeuilleRelationState();
}

class _FeuilleRelationState extends State<_FeuilleRelation> {
  final _repo = TransportRepository();
  late final Future<List<ScoreVoyageur>> _scores = _repo
      .voyageursCandidats()
      .then((cands) => TransportIa.classerVoyageurs(widget.commande, cands));
  late final Future<List<Transporteur>> _fiches = _repo.transporteurs();
  int? _voyageurChoisi;
  int? _transporteurChoisi;
  bool _envoi = false;

  Future<void> _proposer() async {
    final voyageur = _voyageurChoisi;
    final commandeId = widget.commande.id;
    if (voyageur == null || commandeId == null) return;
    setState(() => _envoi = true);
    final erreur = await _repo.proposerVoyageur(
      commandeId: commandeId,
      auteurId: widget.auteurId,
      voyageurId: voyageur,
      transporteurId: _transporteurChoisi,
    );
    if (!mounted) return;
    if (erreur != null) {
      setState(() => _envoi = false);
      montrerMessage(context, erreur);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.commande;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mettre en relation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            LigneTrajet(depart: c.depart, arrivee: c.arrivee),
            const SizedBox(height: 16),
            const Text('Voyageurs suggérés',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FutureBuilder<List<ScoreVoyageur>>(
              future: _scores,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data ?? const <ScoreVoyageur>[];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Aucun voyageur disponible pour le moment.',
                        style: TextStyle(color: AppColors.grey)),
                  );
                }
                return Column(
                  children: [
                    for (final s in items) ...[
                      _LigneVoyageur(
                        score: s,
                        selectionne: _voyageurChoisi == s.voyageur.id,
                        onTap: () =>
                            setState(() => _voyageurChoisi = s.voyageur.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Transporteur>>(
              future: _fiches,
              builder: (context, snap) {
                final fiches = snap.data ?? const <Transporteur>[];
                return DropdownButtonFormField<int?>(
                  initialValue: _transporteurChoisi,
                  decoration: const InputDecoration(
                    labelText: 'Transporteur (facultatif)',
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Aucun transporteur')),
                    for (final t in fiches)
                      DropdownMenuItem<int?>(
                          value: t.id, child: Text('${t.nom} (${t.type})')),
                  ],
                  onChanged: (v) => setState(() => _transporteurChoisi = v),
                );
              },
            ),
            const SizedBox(height: 20),
            TravelButton(
              texte: 'Proposer ce voyageur',
              chargement: _envoi,
              onPressed: _voyageurChoisi == null ? null : _proposer,
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneVoyageur extends StatelessWidget {
  final ScoreVoyageur score;
  final bool selectionne;
  final VoidCallback onTap;

  const _LigneVoyageur({
    required this.score,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nom = score.voyageur.nom;
    return Material(
      color: selectionne ? AppColors.tealLight : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selectionne ? AppColors.teal : AppColors.border,
          width: selectionne ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.teal,
                child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(score.raison,
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${score.score}',
                    style: const TextStyle(
                        color: AppColors.orangeText,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
