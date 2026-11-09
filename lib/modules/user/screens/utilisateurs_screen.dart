import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../admin_repository.dart';
import '../role.dart';
import '../utilisateur.dart';
import 'garde_admin.dart';

/// Liste des comptes (administrateur). Un compte client, voyageur ou transporteur
/// peut être supprimé ; l'administrateur ne supprime jamais son propre compte.
class UtilisateursScreen extends StatelessWidget {
  const UtilisateursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GardeAdmin(
      titre: 'Utilisateurs',
      enfant: _ContenuUtilisateurs(),
    );
  }
}

class _ContenuUtilisateurs extends StatefulWidget {
  const _ContenuUtilisateurs();

  @override
  State<_ContenuUtilisateurs> createState() => _ContenuUtilisateursState();
}

class _Donnees {
  final List<Utilisateur> utilisateurs;
  final int? adminId;

  const _Donnees(this.utilisateurs, this.adminId);
}

class _ContenuUtilisateursState extends State<_ContenuUtilisateurs> {
  final _repo = AdminRepository();
  late Future<_Donnees> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<_Donnees> _charger() async {
    final adminId = await SessionService.instance.utilisateurId();
    final utilisateurs = await _repo.utilisateurs();
    return _Donnees(utilisateurs, adminId);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _supprimer(Utilisateur u, int adminId) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ${u.nomComplet} ?',
      message: 'Ses voyages, locations, séjours, commandes et avis seront '
          'supprimés définitivement.',
    );
    if (!ok || !mounted) return;
    final erreur = await _repo.supprimerUtilisateur(u.id!, adminId);
    if (!mounted) return;
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    afficherMessage(context, 'Compte supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Utilisateurs',
      corps: FutureBuilder<_Donnees>(
        future: _futur,
        builder: (context, snap) {
          if (snap.hasError) {
            return EtatVideModule(
              icone: Icons.error_outline,
              titre: 'Chargement impossible',
              message: '${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final donnees = snap.data!;
          final liste = donnees.utilisateurs;
          return RefreshIndicator(
            onRefresh: _recharger,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                EnTeteModule(
                  titre: 'Utilisateurs',
                  sousTitre: 'Comptes inscrits sur la plateforme.',
                  icone: Icons.people_outline,
                  indicateurs: [
                    IndicateurEnTete(
                      valeur: '${liste.length}',
                      libelle: 'comptes',
                      icone: Icons.people_outline,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    children: [
                      for (final u in liste)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _carte(u, donnees.adminId),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _carte(Utilisateur u, int? adminId) {
    final estMoi = adminId != null && u.id == adminId;
    final supprimable = u.role != Role.admin && !estMoi;
    return CarteModule(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.tealLight,
            child: Text(u.initiales,
                style: const TextStyle(
                    color: AppColors.teal, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(estMoi ? '${u.nomComplet} (vous)' : u.nomComplet,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(u.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(u.role.libelle,
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          if (supprimable)
            IconButton(
              tooltip: 'Supprimer le compte',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _supprimer(u, adminId!),
            ),
        ],
      ),
    );
  }
}
