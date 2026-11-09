import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../user/user_repository.dart';
import '../models/commande_transport.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';
import 'commande_form_screen.dart';

/// Liste des commandes du client connecté (UI Kit : « Mes commandes »).
/// Les coordonnées du voyageur n'apparaissent qu'une fois la commande acceptée.
class MesCommandesScreen extends StatefulWidget {
  const MesCommandesScreen({super.key});

  @override
  State<MesCommandesScreen> createState() => _MesCommandesScreenState();
}

class _MesCommandesScreenState extends State<MesCommandesScreen> {
  final _repo = TransportRepository();
  int? _clientId;
  bool _charge = false;
  Future<List<CommandeTransport>>? _liste;

  @override
  void initState() {
    super.initState();
    _chargerClient();
  }

  Future<void> _chargerClient() async {
    final u = await UserRepository().utilisateurConnecte();
    if (!mounted) return;
    final id = u?.id;
    setState(() {
      _charge = true;
      _clientId = id;
      _liste = id == null ? null : _repo.commandesDuClient(id);
    });
  }

  void _recharger() {
    final id = _clientId;
    if (id == null) return;
    setState(() => _liste = _repo.commandesDuClient(id));
  }

  Future<bool> _confirmer(String titre, String texte) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
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
    return ok == true;
  }

  Future<void> _modifier(CommandeTransport c) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CommandeFormScreen(commande: c)));
    _recharger();
  }

  Future<void> _annuler(CommandeTransport c) async {
    final id = _clientId;
    if (id == null || c.id == null) return;
    final ok = await _confirmer('Annuler la commande ?',
        'Les transporteurs ne verront plus cette commande.');
    if (!ok || !mounted) return;
    final annulee = await _repo.annulerCommande(c.id!, id);
    if (!mounted) return;
    montrerMessage(context,
        annulee ? 'Commande annulée' : 'Cette commande ne peut plus être annulée');
    _recharger();
  }

  Future<void> _supprimer(CommandeTransport c) async {
    final id = _clientId;
    if (id == null || c.id == null) return;
    final ok = await _confirmer('Supprimer la commande ?',
        'Cette action est définitive.');
    if (!ok || !mounted) return;
    final supprimee = await _repo.supprimerCommande(c.id!, id);
    if (!mounted) return;
    montrerMessage(context,
        supprimee ? 'Commande supprimée' : 'Impossible de supprimer une commande acceptée');
    _recharger();
  }

  Future<void> _nouvelle() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CommandeFormScreen()));
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(
      titre: 'Mes commandes',
      boutonFlottant: FloatingActionButton.extended(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.white,
        onPressed: _nouvelle,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: _corps(),
    );
  }

  Widget _corps() {
    if (!_charge) return const Center(child: CircularProgressIndicator());
    final liste = _liste;
    if (liste == null) {
      return const EtatVide(
          icone: Icons.lock_outline,
          message: 'Connectez-vous pour voir vos commandes.');
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
                      icone: Icons.assignment_outlined,
                      message:
                          'Aucune commande pour le moment.\nAppuyez sur « Nouvelle » pour commencer.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return _CarteCommande(
                      commande: c,
                      onModifier: c.statut == StatutCommande.ouverte
                          ? () => _modifier(c)
                          : null,
                      onAnnuler: c.statut == StatutCommande.ouverte
                          ? () => _annuler(c)
                          : null,
                      onSupprimer: c.statut == StatutCommande.acceptee
                          ? null
                          : () => _supprimer(c),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _CarteCommande extends StatelessWidget {
  final CommandeTransport commande;
  final VoidCallback? onModifier;
  final VoidCallback? onAnnuler;
  final VoidCallback? onSupprimer;

  const _CarteCommande({
    required this.commande,
    this.onModifier,
    this.onAnnuler,
    this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final c = commande;
    final actions = [
      if (onModifier != null)
        TextButton.icon(
            onPressed: onModifier,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier')),
      if (onAnnuler != null)
        TextButton.icon(
            onPressed: onAnnuler,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Annuler')),
      if (onSupprimer != null)
        TextButton.icon(
            onPressed: onSupprimer,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Supprimer')),
    ];
    return CarteTransport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: LigneTrajet(depart: c.depart, arrivee: c.arrivee)),
              const SizedBox(width: 8),
              BadgeStatut(libelle: c.statut.libelle, valeur: c.statut.valeur),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${dateCourte(c.dateSouhaitee)} · Budget ${TransportFormat.prix(c.budget)}',
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
          ),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
          ],
          if (c.statut == StatutCommande.acceptee) ...[
            const SizedBox(height: 12),
            BlocContact(
                titre: 'VOTRE VOYAGEUR',
                nom: c.nomVoyageur,
                contact: c.contactVoyageur),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, children: actions),
          ],
        ],
      ),
    );
  }
}
