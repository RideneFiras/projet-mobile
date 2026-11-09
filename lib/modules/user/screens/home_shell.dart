import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../hebergement/hebergement_routes.dart';
import '../../location/location_routes.dart';
import '../role.dart';
import '../user_repository.dart';
import '../utilisateur.dart';
import 'accueil_tab.dart';
import 'actualites_tab.dart';
import 'profil_tab.dart';

/// Coque commune après connexion (UI Kit) : barre du bas Accueil / Actualités / Profil.
/// L'accueil affiché dépend du rôle de l'utilisateur (relu en base).
/// Le menu latéral (☰) donne aussi accès aux écrans de gestion de l'administrateur.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _repo = UserRepository();
  Utilisateur? _utilisateur;
  int _onglet = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final u = await _repo.utilisateurConnecte();
    if (!mounted) return;
    if (u == null) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }
    setState(() => _utilisateur = u);
  }

  Future<void> _deconnecter() async {
    await _repo.deconnecter();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = _utilisateur;
    if (u == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      drawer: _menu(u),
      body: IndexedStack(
        index: _onglet,
        children: [
          AccueilTab(
            utilisateur: u,
            voirActualites: () => setState(() => _onglet = 1),
          ),
          const ActualitesTab(),
          ProfilTab(
            utilisateur: u,
            onModifie: (nouveau) => setState(() => _utilisateur = nouveau),
            onDeconnexion: _deconnecter,
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: (i) => setState(() => _onglet = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.newspaper_outlined),
              label: 'Actualités',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Drawer _menu(Utilisateur u) {
    void aller(int i) {
      Navigator.pop(context);
      setState(() => _onglet = i);
    }

    void ouvrirModule(String route) {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.teal),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.nomComplet,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text(u.email, style: const TextStyle(color: AppColors.white)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Accueil'),
            onTap: () => aller(0),
          ),
          ListTile(
            leading: const Icon(Icons.newspaper_outlined),
            title: const Text('Actualités'),
            onTap: () => aller(1),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profil'),
            onTap: () => aller(2),
          ),
          if (u.role == Role.admin) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Gérer la flotte'),
              onTap: () => ouvrirModule(LocationRoutes.gestion),
            ),
            ListTile(
              leading: const Icon(Icons.bed_outlined),
              title: const Text('Gérer les établissements'),
              onTap: () => ouvrirModule(HebergementRoutes.gestion),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Se déconnecter',
                style: TextStyle(color: AppColors.danger)),
            onTap: _deconnecter,
          ),
        ],
      ),
    );
  }
}
