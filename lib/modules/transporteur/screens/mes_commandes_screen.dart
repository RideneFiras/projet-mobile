import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/commande_transport.dart';
import '../transport_actualisation.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';
import 'commande_form_screen.dart';

/// Mes commandes : suivi des demandes du voyageur,
/// modification tant qu'elles sont en attente, annulation selon les règles.
class MesCommandesScreen extends StatefulWidget {
  const MesCommandesScreen({super.key});

  @override
  State<MesCommandesScreen> createState() => _MesCommandesScreenState();
}

class _MesCommandesScreenState extends State<MesCommandesScreen> {
  final _repo = TransportRepository();
  bool _charge = false;
  int? _uid;
  Future<List<CommandeTransport>>? _liste;
  ActualisationAuto? _actu;

  @override
  void initState() {
    super.initState();
    _charger();
    _actu = ActualisationAuto(rafraichir: _recharger)..demarrer();
  }

  @override
  void dispose() {
    _actu?.arreter();
    super.dispose();
  }


  Future<void> _charger() async {
    final u = await utilisateurAutorise();
    if (!mounted) return;
    setState(() {
      _uid = u?.id;
      _liste = _requete();
      _charge = true;
    });
  }

  Future<List<CommandeTransport>>? _requete() {
    final id = _uid;
    return id == null ? null : _repo.commandesDuVoyageur(id);
  }

  void _recharger() => setState(() => _liste = _requete());

  Future<void> _ouvrirFormulaire({CommandeTransport? commande}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommandeFormScreen(commande: commande)),
    );
    if (mounted) _recharger();
  }

  Future<void> _annuler(CommandeTransport c) async {
    final id = c.id;
    final uid = _uid;
    if (id == null || uid == null) return;
    var motif = '';
    if (c.statut == StatutCommande.acceptee) {
      final saisi = await demanderMotif(
        context,
        titre: 'Annuler ma réservation ?',
        action: 'Annuler la réservation',
        message: "Annulation possible jusqu'à 24 h avant le départ. Le motif est obligatoire.",
      );
      if (saisi == null || !mounted) return;
      motif = saisi;
    } else {
      final ok = await confirmer(
        context,
        titre: 'Annuler cette demande ?',
        message: 'Les transporteurs sollicités ne verront plus cette demande.',
        action: 'Annuler la demande',
      );
      if (!ok || !mounted) return;
    }
    final erreur = await _repo.annulerCommande(id, uid, motif: motif);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Annulation enregistrée', erreur: erreur != null);
    _recharger();
  }

  Future<void> _supprimer(CommandeTransport c) async {
    final id = c.id;
    final uid = _uid;
    if (id == null || uid == null) return;
    final ok = await confirmer(
      context,
      titre: 'Supprimer cette demande ?',
      message: 'Elle disparaîtra de votre liste.',
    );
    if (!ok || !mounted) return;
    final erreur = await _repo.supprimerCommande(id, uid);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Demande supprimée', erreur: erreur != null);
    _recharger();
  }

  Future<void> _historique(int reservationId) async {
    final evenements = await _repo.historique(reservationId);
    if (!mounted) return;
    await afficherHistorique(context, evenements);
  }

  @override
  Widget build(BuildContext context) {
    const titre = 'Mes commandes';
    if (!_charge) {
      return const EcranModule(
        titre: titre,
        corps: Center(child: CircularProgressIndicator()),
      );
    }
    final liste = _liste;
    if (liste == null) {
      return const EcranModule(
        titre: titre,
        corps: EtatVideModule(
          icone: Icons.lock_outline,
          titre: 'Connexion requise',
          message: 'Connectez-vous pour voir vos demandes.',
        ),
      );
    }
    return EcranModule(
      titre: titre,
      boutonFlottant: BoutonAjouterTransport(
        libelle: 'Nouvelle demande',
        onPressed: () => _ouvrirFormulaire(),
      ),
      corps: FutureBuilder<List<CommandeTransport>>(
        future: liste,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <CommandeTransport>[];
          final acceptees = items.where((c) => c.acceptee).length;
          return CorpsListeTransport(
            onRefresh: () async => _recharger(),
            entete: EnTeteModule(
              titre: 'Mes commandes',
              sousTitre: 'Vos demandes de transport, leur suivi et vos tickets.',
              icone: Icons.receipt_long_outlined,
              indicateurs: [
                IndicateurEnTete(
                    valeur: '${items.length}',
                    libelle: 'demandes',
                    icone: Icons.receipt_long_outlined),
                IndicateurEnTete(
                    valeur: '$acceptees',
                    libelle: 'acceptées',
                    icone: Icons.check_circle_outline),
              ],
            ),
            enfants: [
              if (items.isEmpty)
                EtatVideModule(
                  icone: Icons.receipt_long_outlined,
                  titre: 'Aucune demande',
                  message: 'Envoyez votre première demande de transport.',
                  libelleAction: 'Nouvelle demande',
                  onAction: () => _ouvrirFormulaire(),
                ),
              for (final c in items) _carte(c),
            ],
          );
        },
      ),
    );
  }

  Widget _carte(CommandeTransport c) {
    final reservation = c.reservationId;
    return CarteTransport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: LigneTrajet(depart: c.depart, arrivee: c.arrivee)),
              const SizedBox(width: 8),
              Pastille(libelle: c.statut.libelle, valeur: c.statut.valeur.toLowerCase()),
            ],
          ),
          const SizedBox(height: 4),
          Text('Réf. ${c.reference}',
              style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          LigneInfo(
            icone: Icons.event_outlined,
            texte: '${dateCourte(c.dateVoyage)} à ${TransportFormat.heure(c.dateVoyage)}',
          ),
          const SizedBox(height: 4),
          LigneInfo(
            icone: Icons.group_outlined,
            texte: '${c.nombrePassagers} passager(s) · '
                '${c.prixPropose > 0 ? 'budget ${TransportFormat.prix(c.prixPropose)}' : 'sans budget'}',
          ),
          if (c.statut == StatutCommande.enAttente) ...[
            const SizedBox(height: 4),
            LigneInfo(
              icone: Icons.send_outlined,
              texte: c.nbPropositions == 0
                  ? "Aucun transporteur compatible pour l'instant"
                  : '${c.nbPropositions} transporteur(s) sollicité(s)',
            ),
          ],
          if (c.acceptee) ...[
            const SizedBox(height: 10),
            BlocContact(
              titre: 'Transporteur',
              nom: c.nomTransporteur.isEmpty ? null : c.nomTransporteur,
              contact: c.telephoneTransporteur.isEmpty ? null : c.telephoneTransporteur,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (c.modifiable)
                TextButton.icon(
                  onPressed: () => _ouvrirFormulaire(commande: c),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              if (reservation != null)
                TextButton.icon(
                  onPressed: () => _historique(reservation),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historique'),
                ),
              if (c.annulable)
                OutlinedButton(
                  onPressed: () => _annuler(c),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  child: Text(c.acceptee ? 'Annuler la réservation' : 'Annuler'),
                ),
              if (!c.annulable && !c.acceptee)
                TextButton(
                  onPressed: () => _supprimer(c),
                  child: const Text('Supprimer'),
                ),
            ],
          ),
          if (c.acceptee)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                "Annulation possible jusqu'à 24 h avant le départ, avec un motif.",
                style: TextStyle(color: AppColors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
