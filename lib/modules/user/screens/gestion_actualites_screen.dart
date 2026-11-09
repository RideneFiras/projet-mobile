import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../admin_repository.dart';
import 'actualite_form_screen.dart';
import 'garde_admin.dart';

/// Gestion des actualités (administrateur) : liste, publication, modification, suppression.
class GestionActualitesScreen extends StatelessWidget {
  const GestionActualitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GardeAdmin(
      titre: 'Gérer les actualités',
      enfant: _ContenuActualites(),
    );
  }
}

class _ContenuActualites extends StatefulWidget {
  const _ContenuActualites();

  @override
  State<_ContenuActualites> createState() => _ContenuActualitesState();
}

class _ContenuActualitesState extends State<_ContenuActualites> {
  final _repo = AdminRepository();
  late Future<List<Actualite>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _repo.actualites();
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _repo.actualites();
    });
    await _futur;
  }

  Future<void> _publier() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ActualiteFormScreen()),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Actualité publiée');
      await _recharger();
    }
  }

  Future<void> _modifier(Actualite a) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ActualiteFormScreen(actualite: a)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _supprimer(Actualite a) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer cette actualité ?',
      message: '« ${a.titre} » ne sera plus visible par les utilisateurs.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerActualite(a.id!);
    if (!mounted) return;
    afficherMessage(context, 'Actualité supprimée');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Gérer les actualités',
      boutonFlottant: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _publier,
      ),
      corps: FutureBuilder<List<Actualite>>(
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
          final liste = snap.data!;
          return RefreshIndicator(
            onRefresh: _recharger,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                EnTeteModule(
                  titre: 'Actualités',
                  sousTitre: '',
                  icone: Icons.campaign_outlined,
                  indicateurs: [
                    IndicateurEnTete(
                      valeur: '${liste.length}',
                      libelle: 'publiées',
                      icone: Icons.article_outlined,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: liste.isEmpty
                      ? EtatVideModule(
                          icone: Icons.campaign_outlined,
                          titre: 'Aucune actualité',
                          message: 'Publiez la première actualité de la plateforme.',
                          libelleAction: 'Publier',
                          onAction: _publier,
                        )
                      : Column(
                          children: [for (final a in liste) _carte(a)],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _carte(Actualite a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CarteModule(
        accent: AppColors.orange,
        onTap: () => _modifier(a),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.titre,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(a.contenu,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              Pastille(libelle: a.categorie.libelle, valeur: 'valide'),
              Pastille(libelle: a.audience.libelle, valeur: 'ouverte'),
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(dateCourte(a.datePublication),
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                  onPressed: () => _modifier(a),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(a),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
