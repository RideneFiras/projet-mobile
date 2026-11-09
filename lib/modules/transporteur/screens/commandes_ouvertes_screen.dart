import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../user/role.dart';
import '../../user/utilisateur.dart';
import '../models/mise_en_relation.dart';
import '../transport_actualisation.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Commandes ouvertes : demandes de voyageurs compatibles avec un de vos trajets.
/// Accepter confirme la réservation. Refuser retire la proposition de vos demandes.
class CommandesOuvertesScreen extends StatefulWidget {
  const CommandesOuvertesScreen({super.key});

  @override
  State<CommandesOuvertesScreen> createState() => _CommandesOuvertesScreenState();
}

class _CommandesOuvertesScreenState extends State<CommandesOuvertesScreen> {
  final _repo = TransportRepository();
  bool _charge = false;
  Utilisateur? _utilisateur;
  Future<List<MiseEnRelation>>? _liste;
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
    final u = await utilisateurAutorise(role: Role.transporter);
    if (!mounted) return;
    setState(() {
      _utilisateur = u;
      _liste = _requete();
      _charge = true;
    });
  }

  Future<List<MiseEnRelation>>? _requete() {
    final id = _utilisateur?.id;
    if (id == null) return null;
    return _repo.relationsDuTransporteur(id, statut: StatutRelation.proposee);
  }

  void _recharger() => setState(() => _liste = _requete());

  Future<void> _accepter(MiseEnRelation m) async {
    final id = _utilisateur?.id;
    final relationId = m.id;
    if (id == null || relationId == null) return;
    final erreur = await _repo.repondreProposition(
        relationId: relationId, utilisateurId: id, accepter: true);
    if (!mounted) return;
    afficherMessage(
      context,
      erreur ?? 'Réservation confirmée. Les coordonnées du voyageur sont visibles.',
      erreur: erreur != null,
    );
    _recharger();
  }

  Future<void> _refuser(MiseEnRelation m) async {
    final id = _utilisateur?.id;
    final relationId = m.id;
    if (id == null || relationId == null) return;
    final ok = await confirmer(
      context,
      titre: 'Refuser cette demande ?',
      message: 'Cette proposition sera retirée de vos commandes ouvertes.',
      action: 'Refuser',
    );
    if (!ok || !mounted) return;
    final erreur = await _repo.repondreProposition(
        relationId: relationId, utilisateurId: id, accepter: false);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Demande refusée', erreur: erreur != null);
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    const titre = 'Commandes ouvertes';
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
          icone: Icons.inbox_outlined,
          titre: 'Accès réservé',
          message: 'Cet écran est réservé aux comptes transporteur.',
        ),
      );
    }
    return EcranModule(
      titre: titre,
      corps: FutureBuilder<List<MiseEnRelation>>(
        future: liste,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final erreur = snap.hasError;
          if (erreur) debugPrint('Commandes ouvertes : ${snap.error}');
          final items = erreur ? const <MiseEnRelation>[] : (snap.data ?? const <MiseEnRelation>[]);
          return CorpsListeTransport(
            onRefresh: () async => _recharger(),
            entete: EnTeteModule(
              titre: 'Commandes ouvertes',
              sousTitre: 'Demandes compatibles avec vos trajets. Accepter confirme la réservation.',
              icone: Icons.inbox_outlined,
              indicateurs: [
                IndicateurEnTete(
                    valeur: '${items.length}',
                    libelle: 'en attente',
                    icone: Icons.hourglass_empty),
              ],
            ),
            enfants: [
              if (erreur)
                EtatVideModule(
                  icone: Icons.error_outline,
                  titre: 'Impossible de charger les demandes',
                  message: 'Une erreur est survenue. Réessayez.',
                  libelleAction: 'Réessayer',
                  onAction: _recharger,
                ),
              if (!erreur && items.isEmpty)
                const EtatVideModule(
                  icone: Icons.inbox_outlined,
                  titre: 'Aucune commande ouverte',
                  message: 'Les nouvelles demandes compatibles avec vos trajets apparaîtront ici.',
                ),
              for (final m in items) _carte(m),
            ],
          );
        },
      ),
    );
  }

  Widget _carte(MiseEnRelation m) {
    final peutAccepter = m.placesLibres >= m.nombrePassagers;
    return CarteTransport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: LigneTrajet(depart: m.depart, arrivee: m.arrivee)),
              const SizedBox(width: 8),
              const Pastille(libelle: 'En attente', valeur: 'proposee'),
            ],
          ),
          const SizedBox(height: 4),
          Text('Réf. ${m.reference}',
              style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          LigneInfo(
            icone: Icons.event_outlined,
            texte: '${dateCourte(m.dateVoyage)} à ${TransportFormat.heure(m.dateVoyage)}',
          ),
          const SizedBox(height: 4),
          LigneInfo(
            icone: Icons.group_outlined,
            texte: '${m.nombrePassagers} passager(s) · '
                '${m.prixPropose > 0 ? 'budget ${TransportFormat.prix(m.prixPropose)}' : 'sans budget'}',
          ),
          const SizedBox(height: 4),
          LigneInfo(
            icone: Icons.airline_seat_recline_normal,
            texte: '${m.placesLibres} place(s) libre(s) · '
                '${TransportFormat.prix(m.prixParPersonne)} par personne',
          ),
          if (!peutAccepter) ...[
            const SizedBox(height: 8),
            const Text(
              'Places insuffisantes : acceptation impossible.',
              style: TextStyle(
                  color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: peutAccepter ? () => _accepter(m) : null,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  child: const Text('Accepter'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _refuser(m),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Refuser'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
