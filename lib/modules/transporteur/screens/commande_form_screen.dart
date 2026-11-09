import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/commande_transport.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Demande de transport du voyageur : création, ou modification tant qu'elle est en attente.
class CommandeFormScreen extends StatefulWidget {
  final CommandeTransport? commande;
  final String? departInitial;
  final String? arriveeInitiale;
  final DateTime? dateInitiale;

  const CommandeFormScreen({
    super.key,
    this.commande,
    this.departInitial,
    this.arriveeInitiale,
    this.dateInitiale,
  });

  @override
  State<CommandeFormScreen> createState() => _CommandeFormScreenState();
}

class _CommandeFormScreenState extends State<CommandeFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = TransportRepository();
  final _depart = TextEditingController();
  final _arrivee = TextEditingController();
  final _heure = TextEditingController();
  final _passagers = TextEditingController();
  final _budget = TextEditingController();
  final _commentaire = TextEditingController();
  DateTime? _jour;
  String? _erreurDate;
  int? _utilisateurId;
  bool _charge = false;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    final c = widget.commande;
    final date = c?.dateVoyage ?? widget.dateInitiale;
    _depart.text = c?.depart ?? widget.departInitial ?? '';
    _arrivee.text = c?.arrivee ?? widget.arriveeInitiale ?? '';
    _jour = date == null ? null : dateJour(date);
    _heure.text = date == null ? '09:00' : TransportFormat.heure(date);
    _passagers.text = '${c?.nombrePassagers ?? 1}';
    _budget.text =
        c == null || c.prixPropose == 0 ? '' : c.prixPropose.toStringAsFixed(2);
    _commentaire.text = c?.commentaire ?? '';
    _chargerUtilisateur();
  }

  @override
  void dispose() {
    for (final c in [
      _depart,
      _arrivee,
      _heure,
      _passagers,
      _budget,
      _commentaire,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await utilisateurAutorise();
    if (!mounted) return;
    setState(() {
      _utilisateurId = u?.id;
      _charge = true;
    });
  }

  Future<void> _enregistrer() async {
    final uid = _utilisateurId;
    final erreurDate = TransportFormat.validerDateFuture(_jour);
    setState(() => _erreurDate = erreurDate);
    if (uid == null || erreurDate != null || !_cle.currentState!.validate()) return;
    final dateVoyage = TransportFormat.combiner(_jour, _heure.text);
    final passagers = TransportFormat.parserEntier(_passagers.text);
    final budgetTexte = _budget.text.trim();
    final budget = budgetTexte.isEmpty ? 0 : TransportFormat.parserMontant(budgetTexte);
    if (dateVoyage == null || passagers == null || budget == null) return;
    if (dateVoyage.isBefore(DateTime.now())) {
      afficherMessage(context, "L'heure de départ est déjà passée", erreur: true);
      return;
    }
    final commande = CommandeTransport(
      id: widget.commande?.id,
      reference: widget.commande?.reference ?? '',
      voyageurId: uid,
      depart: _depart.text,
      arrivee: _arrivee.text,
      dateVoyage: dateVoyage,
      nombrePassagers: passagers,
      prixPropose: TransportFormat.depuisCentimes(budget),
      commentaire: _commentaire.text,
      creeLe: widget.commande?.creeLe ?? DateTime.now(),
    );
    setState(() => _occupe = true);
    final String? erreur;
    final String message;
    if (widget.commande == null) {
      final r = await _repo.creerCommande(commande);
      erreur = null;
      message = r.propositions == 0
          ? "Demande enregistrée : aucun transporteur compatible pour l'instant."
          : 'Demande envoyée à ${r.propositions} transporteur(s).';
    } else {
      erreur = await _repo.modifierCommande(commande, uid);
      message = 'Demande modifiée et relancée auprès des transporteurs.';
    }
    if (!mounted) return;
    setState(() => _occupe = false);
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    afficherMessage(context, message);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final modification = widget.commande != null;
    final titre = modification ? 'Modifier la demande' : 'Nouvelle demande';
    if (!_charge) {
      return EcranModule(
        titre: titre,
        corps: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_utilisateurId == null) {
      return EcranModule(
        titre: titre,
        corps: const EtatVideModule(
          icone: Icons.lock_outline,
          titre: 'Connexion requise',
          message: 'Connectez-vous pour envoyer une demande de transport.',
        ),
      );
    }
    return EcranModule(
      titre: titre,
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            ChampTexte(
              controller: _depart,
              label: 'Ville de départ',
              icone: Icons.trip_origin,
              capitalisation: TextCapitalization.words,
              validateur: (v) => TransportFormat.validerVille(v, champ: 'La ville de départ'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _arrivee,
              label: "Ville d'arrivée",
              icone: Icons.flag_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) =>
                  TransportFormat.validerVille(v, champ: "La ville d'arrivée") ??
                  TransportFormat.validerTrajet(_depart.text, v),
            ),
            const SizedBox(height: 14),
            ChampDate(
              label: 'Date du voyage',
              valeur: _jour,
              erreur: _erreurDate,
              premiereDate: DateTime.now(),
              onChoisie: (d) => setState(() {
                _jour = d;
                _erreurDate = null;
              }),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _heure,
              label: 'Heure de départ (HH:mm)',
              icone: Icons.schedule,
              clavier: TextInputType.datetime,
              validateur: TransportFormat.validerHeure,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _passagers,
              label: 'Nombre de passagers',
              icone: Icons.group_outlined,
              clavier: TextInputType.number,
              validateur: (v) =>
                  TransportFormat.validerEntier(v, champ: 'Le nombre de passagers', max: 20),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _budget,
              label: 'Budget par personne (DT, facultatif)',
              icone: Icons.payments_outlined,
              clavier: TextInputType.numberWithOptions(decimal: true),
              validateur: (v) => TransportFormat.validerMontant(v, obligatoire: false),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _commentaire,
              label: 'Commentaire (facultatif)',
              icone: Icons.notes_outlined,
              lignes: 3,
            ),
            const SizedBox(height: 24),
            BoutonPrincipal(
              libelle: modification ? 'Enregistrer les modifications' : 'Envoyer la demande',
              icone: Icons.send_outlined,
              onPressed: _occupe ? null : _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
