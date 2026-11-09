import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../../user/user_repository.dart';
import '../../user/utilisateur.dart';
import '../models/commande_transport.dart';
import '../transport_format.dart';
import '../transport_ia.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Création ou modification d'une commande client (UI Kit : « Nouvelle commande »).
/// Le client peut décrire la commande en une phrase : l'assistant remplit les champs,
/// et il reste toujours possible de les saisir à la main.
class CommandeFormScreen extends StatefulWidget {
  /// Commande à modifier ; null pour une nouvelle commande.
  final CommandeTransport? commande;

  const CommandeFormScreen({super.key, this.commande});

  @override
  State<CommandeFormScreen> createState() => _CommandeFormScreenState();
}

class _CommandeFormScreenState extends State<CommandeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _texteLibre = TextEditingController();
  late final _depart = TextEditingController(text: widget.commande?.depart);
  late final _arrivee = TextEditingController(text: widget.commande?.arrivee);
  late final _budget = TextEditingController(
      text: widget.commande?.budget.toStringAsFixed(2));
  late final _description =
      TextEditingController(text: widget.commande?.description);
  final _repo = TransportRepository();
  final _utilisateur = UserRepository().utilisateurConnecte();

  late DateTime? _date = widget.commande?.dateSouhaitee;
  String? _erreurDate;
  SourceIa? _sourceIa;
  bool _chargement = false;
  bool _iaEnCours = false;

  bool get _modification => widget.commande != null;

  @override
  void dispose() {
    for (final c in [_texteLibre, _depart, _arrivee, _budget, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _interpreter() async {
    FocusScope.of(context).unfocus();
    final texte = _texteLibre.text.trim();
    if (texte.isEmpty) {
      montrerMessage(context, 'Décrivez d\'abord la commande en une phrase');
      return;
    }
    setState(() => _iaEnCours = true);
    final r = await TransportIa.interpreterCommande(texte);
    if (!mounted) return;
    setState(() {
      _iaEnCours = false;
      _sourceIa = r.source;
      if (r.depart != null) _depart.text = r.depart!;
      if (r.arrivee != null) _arrivee.text = r.arrivee!;
      if (r.date != null) {
        _date = DateTime(r.date!.year, r.date!.month, r.date!.day);
        _erreurDate = null;
      }
      if (r.budget != null) _budget.text = r.budget!.toStringAsFixed(2);
      _description.text = texte;
    });
    if (r.depart == null || r.arrivee == null) {
      montrerMessage(context,
          'Trajet non reconnu : complétez les villes à la main');
    }
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    final dateChangee = _date != widget.commande?.dateSouhaitee;
    setState(() => _erreurDate =
        (!_modification || dateChangee) ? TransportFormat.validerDateFuture(_date) : null);
    if (!_formKey.currentState!.validate() || _erreurDate != null) return;

    final u = await _utilisateur;
    if (u?.id == null || !mounted) return;
    setState(() => _chargement = true);

    final centimes = TransportFormat.parserMontant(_budget.text) ?? 0;
    final commande = CommandeTransport(
      id: widget.commande?.id,
      clientId: u!.id!,
      depart: _depart.text,
      arrivee: _arrivee.text,
      dateSouhaitee: _date!,
      budget: TransportFormat.depuisCentimes(centimes),
      description: _description.text,
      creeLe: widget.commande?.creeLe ?? DateTime.now(),
    );

    final bool ok;
    if (_modification) {
      ok = await _repo.modifierCommande(commande, u.id!);
    } else {
      await _repo.creerCommande(commande);
      ok = true;
    }
    if (!mounted) return;
    setState(() => _chargement = false);
    if (!ok) {
      montrerMessage(context, 'Cette commande ne peut plus être modifiée');
      return;
    }
    montrerMessage(context,
        _modification ? 'Commande mise à jour' : 'Commande publiée');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(
      titre: _modification ? 'Modifier la commande' : 'Nouvelle commande',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_modification) ...[
                _boiteAssistant(),
                const SizedBox(height: 20),
              ],
              const Text('Trajet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TravelField(
                label: "Ville d'achat",
                hint: 'Tunis',
                icone: Icons.storefront_outlined,
                controller: _depart,
                validator: (v) =>
                    TransportFormat.validerVille(v, champ: "La ville d'achat"),
              ),
              const SizedBox(height: 14),
              TravelField(
                label: 'Ville de livraison',
                hint: 'Sfax',
                icone: Icons.place_outlined,
                controller: _arrivee,
                validator: (v) =>
                    TransportFormat.validerTrajet(_depart.text, v) ??
                    TransportFormat.validerVille(v,
                        champ: 'La ville de livraison'),
              ),
              const SizedBox(height: 14),
              ChampDate(
                label: 'Date souhaitée',
                valeur: _date,
                erreur: _erreurDate,
                premiereDate: DateTime.now(),
                onChoisie: (d) => setState(() {
                  _date = d;
                  _erreurDate = null;
                }),
              ),
              const SizedBox(height: 24),
              const Text('Budget',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TravelField(
                label: 'Budget (DT)',
                hint: '50.00',
                icone: Icons.payments_outlined,
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => TransportFormat.validerMontant(v),
              ),
              const SizedBox(height: 14),
              TravelField(
                label: 'Détails (facultatif)',
                hint: 'Colis, taille, contraintes…',
                icone: Icons.notes_outlined,
                controller: _description,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 28),
              TravelButton(
                texte: _modification ? 'Enregistrer' : 'Publier la commande',
                chargement: _chargement,
                onPressed: _enregistrer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zone « décrire la commande » : l'assistant pré-remplit le formulaire.
  Widget _boiteAssistant() {
    return CarteTransport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.orangeText, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Décrire la commande',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Ex : « De Tunis à Sfax demain, budget 50 DT, colis fragile »',
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texteLibre,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Votre phrase…',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                shape: const StadiumBorder(),
              ),
              onPressed: _iaEnCours ? null : _interpreter,
              icon: _iaEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Remplir le formulaire',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_sourceIa != null) ...[
            const SizedBox(height: 10),
            BandeauSource(source: _sourceIa!),
          ],
        ],
      ),
    );
  }
}
