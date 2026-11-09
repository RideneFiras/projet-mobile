import 'package:flutter/material.dart';

import '../../../core/routes/modules_routes.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../actualite.dart';
import '../role.dart';
import '../user_repository.dart';
import '../utilisateur.dart';
import 'widgets_accueil.dart';

/// Raccourci vers un module (écran « à venir » tant que le module n'existe pas).
class _Raccourci {
  final String titre;
  final IconData icone;
  final String module;
  final String responsable;
  const _Raccourci(this.titre, this.icone, this.module, this.responsable);
}

const _voyage = 'Voyage', _dhia = 'Mouhamed Dhia Dridi';
const _transport = 'Transporteur', _abir = 'Abir Gamoudi';
const _location = 'Location', _roua = 'Roua Dhafer';
const _hebergement = 'Hébergement', _oussema = 'Oussema Mrayah';
const _forum = 'Forum', _sirine = 'Sirine Hamzaoui';
const _user = 'User', _abdeslem = 'Abdeslem Kessentini';

/// Accueil propre à chaque rôle, dans la disposition du UI Kit (pages 4 à 7) :
/// titre de section, carte orange ou grille de tuiles, puis « À la une ».
class AccueilTab extends StatefulWidget {
  final Utilisateur utilisateur;
  final VoidCallback voirActualites;

  const AccueilTab(
      {super.key, required this.utilisateur, required this.voirActualites});

  @override
  State<AccueilTab> createState() => _AccueilTabState();
}

class _AccueilTabState extends State<AccueilTab> {
  late Future<List<Actualite>> _actualites;

  @override
  void initState() {
    super.initState();
    _actualites = UserRepository().actualites(limite: 2);
  }

  Future<void> _rafraichir() async {
    setState(() {
      _actualites = UserRepository().actualites(limite: 2);
    });
    await _actualites;
  }

  /// Ouvre la tuile [r] : écran réel s'il existe, sinon écran « à venir ».
  void _ouvrir(_Raccourci r) {
    final route = ModulesRoutes.pour(r.titre);
    if (route != null) {
      Navigator.pushNamed(context, route);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComingSoonScreen(
          titre: r.titre,
          module: r.module,
          responsable: r.responsable,
          icone: r.icone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.utilisateur.role;
    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          EnTeteAccueil(utilisateur: widget.utilisateur),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._contenuDuRole(role),
                const SizedBox(height: 28),
                TitreSection(
                  titre: role == Role.admin ? 'Dernières actualités' : 'À la une',
                  toutVoir: widget.voirActualites,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Actualite>>(
                  future: _actualites,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        for (final a in snap.data!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CarteActualite(actualite: a),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contenu propre au rôle, dans l'ordre de la maquette.
  List<Widget> _contenuDuRole(Role role) {
    switch (role) {
      case Role.client:
        return [
          const TitreSection(titre: 'Raccourcis'),
          const SizedBox(height: 12),
          CarteOrange(
            titre: 'Nouvelle commande',
            sousTitre: "Ville d'achat, livraison et budget",
            icone: Icons.shopping_bag_outlined,
            onTap: () => _ouvrir(const _Raccourci('Nouvelle commande',
                Icons.shopping_bag_outlined, _transport, _abir)),
          ),
          const SizedBox(height: 12),
          _grille(const [
            _Raccourci('Mes commandes', Icons.assignment_outlined, _transport, _abir),
            _Raccourci('Avis sur les transporteurs', Icons.chat_bubble_outline,
                _forum, _sirine),
          ]),
        ];
      case Role.traveller:
        return [
          const TitreSection(titre: 'Votre voyage'),
          const SizedBox(height: 12),
          _grille(const [
            _Raccourci('Mes voyages', Icons.work_outline, _voyage, _dhia),
            _Raccourci('Nouveau voyage', Icons.add, _voyage, _dhia),
            _Raccourci('Transport', Icons.flight_outlined, _transport, _abir),
            _Raccourci('Location de voiture', Icons.directions_car_outlined,
                _location, _roua),
            _Raccourci('Hébergement', Icons.bed_outlined, _hebergement, _oussema),
            _Raccourci('Forum', Icons.chat_bubble_outline, _forum, _sirine),
          ], miseEnAvant: 1),
        ];
      case Role.transporter:
        return [
          const TitreSection(titre: 'Mises en relation'),
          const SizedBox(height: 12),
          CarteOrange(
            titre: 'Commandes ouvertes',
            sousTitre: 'Trouvez le voyageur sur le même trajet',
            icone: Icons.assignment_outlined,
            onTap: () => _ouvrir(const _Raccourci('Commandes ouvertes',
                Icons.assignment_outlined, _transport, _abir)),
          ),
          const SizedBox(height: 12),
          _grille(const [
            _Raccourci('Mises en relation', Icons.swap_horiz, _transport, _abir),
            _Raccourci('Réservations', Icons.event_available_outlined,
                _transport, _abir),
            _Raccourci('Forum', Icons.chat_bubble_outline, _forum, _sirine),
          ]),
        ];
      case Role.admin:
        return [
          const TitreSection(titre: 'Gestion de la plateforme'),
          const SizedBox(height: 12),
          CarteOrange(
            titre: 'Publier une actualité',
            sousTitre: 'Visible par tous les utilisateurs',
            icone: Icons.campaign_outlined,
            onTap: () => _ouvrir(const _Raccourci('Publier une actualité',
                Icons.campaign_outlined, _user, _abdeslem)),
          ),
          const SizedBox(height: 12),
          _grille(const [
            _Raccourci('Gérer les actualités', Icons.edit_outlined, _user, _abdeslem),
            _Raccourci('Utilisateurs', Icons.people_outline, _user, _abdeslem),
          ]),
        ];
    }
  }

  /// Grille 2 colonnes ; [miseEnAvant] = index de la tuile orange.
  Widget _grille(List<_Raccourci> items, {int? miseEnAvant}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        for (var i = 0; i < items.length; i++)
          TuileAccueil(
            titre: items[i].titre,
            icone: items[i].icone,
            miseEnAvant: i == miseEnAvant,
            onTap: () => _ouvrir(items[i]),
          ),
      ],
    );
  }
}
