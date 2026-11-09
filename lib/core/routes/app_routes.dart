import 'package:flutter/material.dart';

import '../../modules/forum/screens/forum_screen.dart';
import '../../modules/forum/forum_routes.dart';
import '../../modules/hebergement/hebergement_routes.dart';
import '../../modules/hebergement/screens/gestion_etablissements_screen.dart';
import '../../modules/hebergement/screens/hebergement_screen.dart';
import '../../modules/location/location_routes.dart';
import '../../modules/location/screens/gestion_flotte_screen.dart';
import '../../modules/location/screens/location_screen.dart';
import '../../modules/transporteur/screens/commande_form_screen.dart';
import '../../modules/transporteur/screens/commandes_ouvertes_screen.dart';
import '../../modules/transporteur/screens/mes_commandes_screen.dart';
import '../../modules/transporteur/screens/relations_screen.dart';
import '../../modules/transporteur/screens/reservations_screen.dart';
import '../../modules/transporteur/screens/voyageur_screen.dart';
import '../../modules/transporteur/transport_routes.dart';
import '../../modules/user/admin_routes.dart';
import '../../modules/user/screens/actualite_form_screen.dart';
import '../../modules/user/screens/garde_admin.dart';
import '../../modules/user/screens/gestion_actualites_screen.dart';
import '../../modules/user/screens/home_shell.dart';
import '../../modules/user/screens/login_screen.dart';
import '../../modules/user/screens/onboarding_screen.dart';
import '../../modules/user/screens/signup_screen.dart';
import '../../modules/user/screens/splash_screen.dart';
import '../../modules/user/screens/utilisateurs_screen.dart';
import '../../modules/voyage/screens/voyage_form_screen.dart';
import '../../modules/voyage/screens/voyages_screen.dart';
import '../../modules/voyage/voyage_routes.dart';

/// Routes nommées. Chaque module ajoute ici SES routes (une section par module).
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String onboarding = '/onboarding';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        signup: (_) => const SignupScreen(),
        onboarding: (_) => const OnboardingScreen(),
        home: (_) => const HomeShell(),

        // Module transporteur (Abir Gamoudi)
        TransportRoutes.commandeNouvelle: (_) => const CommandeFormScreen(),
        TransportRoutes.mesCommandes: (_) => const MesCommandesScreen(),
        TransportRoutes.commandesOuvertes: (_) => const CommandesOuvertesScreen(),
        TransportRoutes.relations: (_) => const RelationsScreen(),
        TransportRoutes.reservations: (_) => const ReservationsScreen(),
        TransportRoutes.voyageur: (_) => const VoyageurScreen(),

        // Module voyage (Mouhamed Dhia Dridi)
        VoyageRoutes.liste: (_) => const VoyagesScreen(),
        VoyageRoutes.nouveau: (_) => const VoyageFormScreen(),

        // Module location (Roua Dhafer)
        LocationRoutes.accueil: (_) => const LocationScreen(),
        LocationRoutes.gestion: (_) => const GardeAdmin(
              titre: 'Gérer la flotte',
              enfant: GestionFlotteScreen(),
            ),

        // Module hébergement (Oussema Mrayah)
        HebergementRoutes.accueil: (_) => const HebergementScreen(),
        HebergementRoutes.gestion: (_) => const GardeAdmin(
              titre: 'Gérer les établissements',
              enfant: GestionEtablissementsScreen(),
            ),

        // Module forum (Sirine Hamzaoui)
        ForumRoutes.forum: (_) => const ForumScreen(),
        ForumRoutes.avis: (_) => const ForumScreen(ongletInitial: 1),

        // Administration (Abdeslem Kessentini)
        AdminRoutes.actualites: (_) => const GestionActualitesScreen(),
        AdminRoutes.actualiteNouvelle: (_) => const GardeAdmin(
              titre: 'Publier une actualité',
              enfant: ActualiteFormScreen(),
            ),
        AdminRoutes.utilisateurs: (_) => const UtilisateursScreen(),
      };
}
