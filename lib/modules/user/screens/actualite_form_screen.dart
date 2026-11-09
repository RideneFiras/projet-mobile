import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/session_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../admin_repository.dart';

/// Publication (actualite == null) ou modification d'une actualité. Réservé à l'admin.
/// Renvoie true à la fermeture si quelque chose a été enregistré.
class ActualiteFormScreen extends StatefulWidget {
  final Actualite? actualite;

  const ActualiteFormScreen({super.key, this.actualite});

  @override
  State<ActualiteFormScreen> createState() => _ActualiteFormScreenState();
}

class _ActualiteFormScreenState extends State<ActualiteFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = AdminRepository();
  late final TextEditingController _titre;
  late final TextEditingController _contenu;
  bool _enregistrement = false;

  bool get _modeEdition => widget.actualite != null;

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController(text: widget.actualite?.titre ?? '');
    _contenu = TextEditingController(text: widget.actualite?.contenu ?? '');
  }

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final adminId = await SessionService.instance.utilisateurId();
    if (!mounted || adminId == null) return;
    setState(() => _enregistrement = true);

    if (_modeEdition) {
      await _repo.modifierActualite(
        widget.actualite!.id!,
        titre: _titre.text,
        contenu: _contenu.text,
      );
    } else {
      await _repo.publier(
        titre: _titre.text,
        contenu: _contenu.text,
        auteurId: adminId,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier l\'actualité' : 'Publier une actualité',
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
              label: 'Contenu',
              icone: Icons.article_outlined,
              lignes: 7,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) => Validators.requis(v, champ: 'Le contenu'),
            ),
            const SizedBox(height: 28),
            BoutonPrincipal(
              libelle: _modeEdition ? 'Enregistrer' : 'Publier',
              icone: Icons.campaign_outlined,
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
