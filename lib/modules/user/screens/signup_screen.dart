import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../role.dart';
import '../user_repository.dart';

/// Inscription (UI Kit, page 3 : « Rejoignez Travel Platform »).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _mdp = TextEditingController();
  final _confirm = TextEditingController();
  final _repo = UserRepository();
  Role _role = Role.traveller;
  bool _chargement = false;

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _tel, _mdp, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _creerCompte() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);
    final erreur = await _repo.inscrire(
      nom: _nom.text,
      prenom: _prenom.text,
      email: _email.text,
      telephone: _tel.text,
      motDePasse: _mdp.text,
      role: _role,
    );
    if (!mounted) return;
    setState(() => _chargement = false);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _retour,
        ),
        title: const Text('Créer un compte'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rejoignez Travel Platform',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Quelques secondes suffisent pour commencer.',
                        style: TextStyle(fontSize: 15, color: AppColors.grey),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TravelField(
                              label: 'Nom',
                              hint: 'Ben Salah',
                              controller: _nom,
                              validator: (v) =>
                                  Validators.requis(v, champ: 'Le nom'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TravelField(
                              label: 'Prénom',
                              hint: 'Sarra',
                              controller: _prenom,
                              validator: (v) =>
                                  Validators.requis(v, champ: 'Le prénom'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TravelField(
                        label: 'Adresse e-mail',
                        hint: 'nom@exemple.com',
                        icone: Icons.mail_outline,
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      TravelField(
                        label: 'Téléphone',
                        hint: '+216 20 123 456',
                        icone: Icons.phone_outlined,
                        controller: _tel,
                        keyboardType: TextInputType.phone,
                        validator: Validators.telephone,
                      ),
                      const SizedBox(height: 14),
                      TravelField(
                        label: 'Mot de passe',
                        hint: '••••••••',
                        icone: Icons.lock_outline,
                        controller: _mdp,
                        motDePasse: true,
                        validator: Validators.motDePasse,
                      ),
                      const SizedBox(height: 14),
                      TravelField(
                        label: 'Confirmer le mot de passe',
                        hint: '••••••••',
                        icone: Icons.lock_outline,
                        controller: _confirm,
                        motDePasse: true,
                        afficherOeil: false,
                        textInputAction: TextInputAction.done,
                        validator: (v) => v != _mdp.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          '8 caractères minimum, avec une lettre et un chiffre.',
                          style: TextStyle(fontSize: 13, color: AppColors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Je suis',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final r in Role.inscription) ...[
                            Expanded(
                              child: _CarteRole(
                                role: r,
                                selectionne: r == _role,
                                onTap: () => setState(() => _role = r),
                              ),
                            ),
                            if (r != Role.inscription.last) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          _role.description,
                          style: const TextStyle(fontSize: 13, color: AppColors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: TravelButton(
                texte: 'Créer mon compte',
                chargement: _chargement,
                onPressed: _creerCompte,
              ),
            ),
            const SizedBox(height: 14),
            TravelLinkRow(
              question: 'Déjà un compte ?',
              lien: 'Se connecter',
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.login, (_) => false),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Carte de choix du rôle (Client / Voyageur / Transporteur) : fond blanc,
/// bordure turquoise 2 px et pastille « ✓ » quand elle est sélectionnée.
class _CarteRole extends StatelessWidget {
  final Role role;
  final bool selectionne;
  final VoidCallback onTap;

  const _CarteRole(
      {required this.role, required this.selectionne, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final couleur = selectionne ? AppColors.teal : AppColors.navy;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectionne ? AppColors.teal : AppColors.border,
                width: selectionne ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(role.icone, color: couleur, size: 28),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    role.libelle,
                    style: TextStyle(
                      color: couleur,
                      fontSize: 14,
                      fontWeight:
                          selectionne ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectionne)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 15, color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }
}
