import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../role.dart';
import '../user_repository.dart';
import '../utilisateur.dart';
import 'widgets_accueil.dart';

/// Profil (UI Kit, page 15) : titre « Mon profil », identité (avatar, nom,
/// e-mail, rôle), informations modifiables ; e-mail et rôle grisés ;
/// « Enregistrer » plein et « Se déconnecter » en contour rouge.
class ProfilTab extends StatefulWidget {
  final Utilisateur utilisateur;
  final ValueChanged<Utilisateur> onModifie;
  final VoidCallback onDeconnexion;

  const ProfilTab({
    super.key,
    required this.utilisateur,
    required this.onModifie,
    required this.onDeconnexion,
  });

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.utilisateur.nom);
  late final _prenom = TextEditingController(text: widget.utilisateur.prenom);
  late final _tel = TextEditingController(text: widget.utilisateur.telephone);
  late final _email = TextEditingController(text: widget.utilisateur.email);
  late final _role =
      TextEditingController(text: widget.utilisateur.role.libelle);
  bool _chargement = false;

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _tel, _email, _role]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);
    final maj = widget.utilisateur.copyWith(
      nom: _nom.text.trim(),
      prenom: _prenom.text.trim(),
      telephone: _tel.text.trim(),
    );
    await UserRepository().mettreAJourProfil(maj);
    if (!mounted) return;
    setState(() => _chargement = false);
    widget.onModifie(maj);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profil enregistré')));
  }

  Future<void> _confirmerDeconnexion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir à nouveau vos identifiants.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Se déconnecter',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) widget.onDeconnexion();
  }

  /// Identité en haut de page : avatar turquoise, nom, e-mail, rôle.
  Widget _identite(Utilisateur u) {
    final voyageur = u.role == Role.traveller;
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
          ),
          child: Text(
            u.initiales,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.nomComplet,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(u.email,
                  style: const TextStyle(fontSize: 14, color: AppColors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: voyageur ? AppColors.orangeLight : AppColors.tealLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  u.role.libelle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: voyageur ? AppColors.orangeText : AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.utilisateur;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mon profil',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            _identite(u),
            const SizedBox(height: 28),
            const TitreSection(titre: 'Informations personnelles'),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TravelField(
                          label: 'Nom',
                          controller: _nom,
                          validator: (v) => Validators.requis(v, champ: 'Le nom'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TravelField(
                          label: 'Prénom',
                          controller: _prenom,
                          validator: (v) =>
                              Validators.requis(v, champ: 'Le prénom'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TravelField(
                    label: 'Téléphone',
                    icone: Icons.phone_outlined,
                    controller: _tel,
                    keyboardType: TextInputType.phone,
                    validator: Validators.telephone,
                  ),
                  const SizedBox(height: 14),
                  TravelField(
                    label: 'Adresse e-mail · non modifiable',
                    icone: Icons.lock_outline,
                    controller: _email,
                    enabled: false,
                  ),
                  const SizedBox(height: 14),
                  TravelField(
                    label: 'Rôle · non modifiable',
                    icone: Icons.lock_outline,
                    controller: _role,
                    enabled: false,
                  ),
                  const SizedBox(height: 24),
                  TravelButton(
                    texte: 'Enregistrer',
                    chargement: _chargement,
                    onPressed: _enregistrer,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _confirmerDeconnexion,
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
