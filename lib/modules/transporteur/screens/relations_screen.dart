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

/// Historique des mises en relation : toutes les demandes reçues, filtrées par réponse.
/// Les coordonnées du voyageur n'apparaissent qu'après acceptation.
class RelationsScreen extends StatefulWidget {
  const RelationsScreen({super.key});

  @override
  State<RelationsScreen> createState() => _RelationsScreenState();
}

class _RelationsScreenState extends State<RelationsScreen> {
  static const List<String> _libelles = ['Toutes', 'En attente', 'Acceptées', 'Refusées'];
  static const List<StatutRelation?> _statuts = [
    null,
    StatutRelation.proposee,
    StatutRelation.acceptee,
    StatutRelation.refusee,
  ];

  final _repo = TransportRepository();
  bool _charge = false;
  Utilisateur? _utilisateur;
  int _filtre = 0;
  Future<List<MiseEnRelation>>? _liste;
  ActualisationAuto? _actu;

  @override
  void initState() {
    super.initState();
    _charger();
    _actu = ActualisationAuto(rafraichir: _rafraichir)..demarrer();
  }

  @override
  void dispose() {
    _actu?.arreter();
    super.dispose();
  }

  /// Recharge la liste sans spinner : les données affichées restent à l'écran.
  void _rafraichir() {
    if (mounted) setState(() => _liste = _requete());
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
    return _repo.relationsDuTransporteur(id, statut: _statuts[_filtre]);
  }

  void _choisirFiltre(int i) => setState(() {
        _filtre = i;
        _liste = _requete();
      });

  @override
  Widget build(BuildContext context) {
    const titre = 'Mises en relation';
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
          icone: Icons.compare_arrows,
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
          final items = snap.data ?? const <MiseEnRelation>[];
          final acceptees = items.where((m) => m.acceptee).length;
          return CorpsListeTransport(
            onRefresh: () async => setState(() => _liste = _requete()),
            selecteur: SelecteurSection(
              libelles: _libelles,
              selection: _filtre,
              onChange: _choisirFiltre,
            ),
            entete: EnTeteModule(
              titre: 'Demandes reçues',
              sousTitre: 'Historique des propositions et de leur réponse.',
              icone: Icons.compare_arrows,
              indicateurs: [
                IndicateurEnTete(
                    valeur: '${items.length}',
                    libelle: 'demandes',
                    icone: Icons.compare_arrows),
                IndicateurEnTete(
                    valeur: '$acceptees',
                    libelle: 'acceptées',
                    icone: Icons.check_circle_outline),
              ],
            ),
            enfants: [
              if (items.isEmpty)
                const EtatVideModule(
                  icone: Icons.compare_arrows,
                  titre: 'Aucune demande',
                  message: 'Les demandes compatibles avec vos trajets apparaîtront ici.',
                ),
              for (final m in items) _carte(m),
            ],
          );
        },
      ),
    );
  }

  /// Accepter ou refuser une proposition en attente. Accepter crée la réservation ;
  /// refuser annule la demande, qui apparaît alors dans Réservations.
  Future<void> _repondre(MiseEnRelation m, {required bool accepter}) async {
    final id = _utilisateur?.id;
    final relationId = m.id;
    if (id == null || relationId == null) return;
    if (!accepter) {
      final ok = await confirmer(
        context,
        titre: 'Refuser cette demande ?',
        message: 'Le voyageur verra sa demande comme refusée.',
        action: 'Refuser',
      );
      if (!ok || !mounted) return;
    }
    final erreur = await _repo.repondreProposition(
        relationId: relationId, utilisateurId: id, accepter: accepter);
    if (!mounted) return;
    afficherMessage(
      context,
      erreur ??
          (accepter
              ? 'Réservation confirmée. Elle apparaît dans Réservations.'
              : 'Demande annulée. Elle apparaît dans Réservations.'),
      erreur: erreur != null,
    );
    setState(() => _liste = _requete());
  }

  Widget _carte(MiseEnRelation m) => CarteTransport(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: LigneTrajet(depart: m.depart, arrivee: m.arrivee)),
                const SizedBox(width: 8),
                Pastille(libelle: m.statut.libelle, valeur: m.statut.valeur),
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
              icone: Icons.history,
              texte: 'Reçue le ${dateCourte(m.creeLe.toLocal())}'
                  '${m.repondueLe == null ? '' : ' · répondue le ${dateCourte(m.repondueLe!.toLocal())}'}',
            ),
            const SizedBox(height: 10),
            BlocContact(
              titre: 'Voyageur',
              nom: m.acceptee ? m.nomVoyageur : null,
              contact: m.acceptee ? m.telephoneVoyageur : null,
            ),
            if (m.enAttente) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _repondre(m, accepter: true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _repondre(m, accepter: false),
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
          ],
        ),
      );
}
