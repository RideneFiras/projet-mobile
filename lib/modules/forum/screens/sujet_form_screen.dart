import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/session_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../forum_repository.dart';
import '../models/sujet_forum.dart';

/// Rédaction d'une discussion (sujet == null) ou modification de la sienne.
/// Renvoie true à la fermeture si quelque chose a été enregistré.
class SujetFormScreen extends StatefulWidget {
  final SujetForum? sujet;

  const SujetFormScreen({super.key, this.sujet});

  @override
  State<SujetFormScreen> createState() => _SujetFormScreenState();
}

class _SujetFormScreenState extends State<SujetFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = ForumRepository();
  late final TextEditingController _titre;
  late final TextEditingController _contenu;
  bool _enregistrement = false;

  bool get _modeEdition => widget.sujet != null;

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController(text: widget.sujet?.titre ?? '');
    _contenu = TextEditingController(text: widget.sujet?.contenu ?? '');
  }

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  String? _validerContenu(String? v) {
    if (v == null || v.trim().length < 10) return 'Au moins 10 caractères';
    return null;
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final userId = await SessionService.instance.utilisateurId();
    if (!mounted || userId == null) return;
    setState(() => _enregistrement = true);

    final sujet = SujetForum(
      id: widget.sujet?.id,
      titre: _titre.text,
      contenu: _contenu.text,
      creeLe: widget.sujet?.creeLe ?? DateTime.now(),
      auteurId: userId,
    );
    var ok = true;
    if (_modeEdition) {
      ok = await _repo.modifierSujet(sujet, userId);
    } else {
      await _repo.creerSujet(sujet);
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _enregistrement = false);
      afficherMessage(context, 'Vous ne pouvez modifier que vos propres messages',
          erreur: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier la discussion' : 'Nouvelle discussion',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ChampTexte(
              controller: _titre,
              label: 'Titre',
              icone: Icons.title,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) => Validators.requis(v, champ: 'Le titre'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _contenu,
              label: 'Votre message',
              icone: Icons.edit_note,
              lignes: 6,
              capitalisation: TextCapitalization.sentences,
              validateur: _validerContenu,
            ),
            const SizedBox(height: 28),
            BoutonPrincipal(
              libelle: _modeEdition ? 'Enregistrer' : 'Publier',
              icone: Icons.send_outlined,
              onPressed: _enregistrement ? null : _enregistrer,
            ),
            const SizedBox(height: 12),
            BoutonSecondaire(
              libelle: 'Annuler',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
