import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/ui_kit.dart';
import '../user/role.dart';
import '../user/user_repository.dart';
import '../user/utilisateur.dart';
import 'models/reservation_transport.dart';
import 'transport_format.dart';

// Composants du module transporteur construits sur l'UI Kit. Ils reprennent le
// style du module voyage (même en-tête, mêmes cartes, mêmes puces, même bouton
// flottant orange). Seuls les éléments propres au transport sont ajoutés ici :
// ligne de trajet, coordonnées de la contrepartie.

/// Bouton flottant orange « Nouveau … », identique à « Nouveau voyage ».
class BoutonAjouterTransport extends StatelessWidget {
  final String libelle;
  final VoidCallback onPressed;

  const BoutonAjouterTransport({
    super.key,
    required this.libelle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onPressed,
      );
}

/// Liste défilante d'un module : l'en-tête défile avec les cartes et on tire pour
/// actualiser, comme « Mes voyages ». [selecteur] : puces facultatives sous l'en-tête.
class CorpsListeTransport extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget entete;
  final Widget? selecteur;
  final List<Widget> enfants;

  const CorpsListeTransport({
    super.key,
    required this.onRefresh,
    required this.entete,
    required this.enfants,
    this.selecteur,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            entete,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecteur != null) ...[
                    selecteur!,
                    const SizedBox(height: 16),
                  ],
                  ...enfants,
                ],
              ),
            ),
          ],
        ),
      );
}

/// Puces de choix de section (ex : Trajets / Transporteurs), style des filtres du voyage.
class SelecteurSection extends StatelessWidget {
  final List<String> libelles;
  final int selection;
  final ValueChanged<int> onChange;

  const SelecteurSection({
    super.key,
    required this.libelles,
    required this.selection,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < libelles.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(libelles[i]),
                  selected: i == selection,
                  onSelected: (_) => onChange(i),
                ),
              ),
          ],
        ),
      );
}

/// Carte du module, avec l'espace de 12 px dessous comme les cartes voyage.
/// [accent] : barre colorée à gauche (couleur du statut).
class CarteTransport extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;

  const CarteTransport({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CarteModule(onTap: onTap, accent: accent, child: child),
      );
}

/// Ligne d'information grise avec icône (date, contact, budget…).
class LigneInfo extends StatelessWidget {
  final IconData icone;
  final String texte;

  const LigneInfo({super.key, required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, size: 16, color: AppColors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texte,
                style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          ),
        ],
      );
}

/// Titre « Départ → Arrivée » en gras, à la taille des titres de voyage.
class LigneTrajet extends StatelessWidget {
  final String depart;
  final String arrivee;

  const LigneTrajet({super.key, required this.depart, required this.arrivee});

  @override
  Widget build(BuildContext context) => Text('$depart → $arrivee',
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
}

/// Coordonnées d'un interlocuteur. Tant que [contact] est nul (mise en relation
/// non acceptée), on affiche seulement une note : aucune coordonnée n'est montrée.
class BlocContact extends StatelessWidget {
  final String titre;
  final String? nom;
  final String? contact;

  const BlocContact({super.key, required this.titre, this.nom, this.contact});

  @override
  Widget build(BuildContext context) {
    if (contact == null || nom == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(12)),
        child: const Text(
          'Coordonnées visibles après acceptation.',
          style: TextStyle(
              color: AppColors.orangeText,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(nom!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(contact!,
                    style: const TextStyle(color: AppColors.navy, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Demande le motif (obligatoire) avant une annulation. Null si l'utilisateur renonce.
Future<String?> demanderMotif(
  BuildContext context, {
  required String titre,
  required String action,
  String message = '',
}) {
  final controleur = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty) ...[
            Text(message, style: const TextStyle(color: AppColors.grey)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: controleur,
            autofocus: true,
            maxLines: 2,
            decoration: decorationUi("Motif de l'annulation"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Retour'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            final texte = controleur.text.trim();
            if (texte.isNotEmpty) Navigator.pop(ctx, texte);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Utilisateur connecté, ou null. Avec [role], seul un compte de ce rôle passe.
Future<Utilisateur?> utilisateurAutorise({Role? role}) async {
  final u = await UserRepository().utilisateurConnecte();
  if (u == null || (role != null && u.role != role)) return null;
  return u;
}

/// Photo ou logo du profil (base64 stocké en base). Null si absente ou illisible.
ImageProvider? imageProfil(String photo) {
  if (photo.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(photo));
  } on FormatException {
    return null;
  }
}

/// Historique d'une réservation, dans une feuille du bas, du plus ancien au plus récent.
Future<void> afficherHistorique(
    BuildContext context, List<EvenementReservation> evenements) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: evenements.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucun événement enregistré.'),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text('Historique',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final e in evenements)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: AppColors.teal),
                    title: Text(e.evenement),
                    subtitle: Text(
                        '${dateCourte(e.creeLe.toLocal())} · '
                        '${TransportFormat.heure(e.creeLe.toLocal())}'),
                  ),
              ],
            ),
    ),
  );
}
