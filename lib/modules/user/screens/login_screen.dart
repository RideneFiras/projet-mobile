import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../../../core/widgets/travel_header.dart';
import '../user_repository.dart';

/// Connexion (UI Kit, page 2 : « Bon retour parmi nous »).
/// En-tête illustré, feuille blanche qui remonte dessus, lien d'inscription en bas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  final _repo = UserRepository();
  bool _chargement = false;

  @override
  void dispose() {
    _email.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);
    final erreur = await _repo.connecter(_email.text, _mdp.text);
    if (!mounted) return;
    setState(() => _chargement = false);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 236 + haut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: TravelWavePainter()),
                Positioned(
                  top: haut + 12,
                  left: 24,
                  child: const Row(
                    children: [
                      TravelLogo(taille: 44),
                      SizedBox(width: 12),
                      Text(
                        'Travel Platform',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 44),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bon retour parmi nous',
                                style: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Connectez-vous pour planifier votre voyage.',
                                style: TextStyle(
                                    fontSize: 16, color: AppColors.grey),
                              ),
                              const SizedBox(height: 28),
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
                                label: 'Mot de passe',
                                hint: '••••••••',
                                icone: Icons.lock_outline,
                                controller: _mdp,
                                motDePasse: true,
                                textInputAction: TextInputAction.done,
                                validator: (v) =>
                                    Validators.requis(v, champ: 'Le mot de passe'),
                              ),
                              const SizedBox(height: 26),
                              TravelButton(
                                texte: 'Se connecter',
                                chargement: _chargement,
                                onPressed: _seConnecter,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TravelLinkRow(
                      question: 'Pas encore de compte ?',
                      lien: 'Créer un compte',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.signup),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
