import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../actualite_fil.dart';
import '../role.dart';
import '../utilisateur.dart';

/// En-tête arrondi « Bonjour, Sarra [Client] ».
class EnTeteAccueil extends StatelessWidget {
  final Utilisateur utilisateur;
  const EnTeteAccueil({super.key, required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    final admin = utilisateur.role == Role.admin;
    final voyageur = utilisateur.role == Role.traveller;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: admin ? AppColors.navy : AppColors.teal,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.paddingOf(context).top + 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.white, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 22,
                backgroundColor: admin ? AppColors.orange : AppColors.tealLight,
                backgroundImage: utilisateur.photo == null
                    ? null
                    : MemoryImage(base64Decode(utilisateur.photo!)),
                child: utilisateur.photo == null
                    ? Text(utilisateur.initiales,
                        style: TextStyle(
                            color: admin ? AppColors.navy : AppColors.teal,
                            fontWeight: FontWeight.w800))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text('Bonjour,',
                style: TextStyle(color: AppColors.white, fontSize: 17)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(utilisateur.prenom,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: voyageur ? AppColors.orangeLight : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(utilisateur.role.libelle,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: voyageur ? AppColors.orangeText : AppColors.navy)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grande carte orange (« Nouvelle commande », « Publier une actualité »...).
class CarteOrange extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final VoidCallback onTap;

  const CarteOrange({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: AppColors.white, shape: BoxShape.circle),
                child: Icon(icone, color: AppColors.navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sousTitre, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile blanche avec icône dans un rond turquoise clair.
class TuileAccueil extends StatelessWidget {
  final String titre;
  final IconData icone;
  final VoidCallback onTap;
  final bool miseEnAvant;

  const TuileAccueil({
    super.key,
    required this.titre,
    required this.icone,
    required this.onTap,
    this.miseEnAvant = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: miseEnAvant ? AppColors.orange : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: miseEnAvant
            ? BorderSide.none
            : const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: miseEnAvant ? AppColors.white : AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone,
                    size: 22,
                    color: miseEnAvant ? AppColors.navy : AppColors.teal),
              ),
              Text(titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'actualité « 15 OCT. 2026 / titre / extrait ».
class CarteActualite extends StatelessWidget {
  final Actualite actualite;
  final bool complete;

  const CarteActualite({super.key, required this.actualite, this.complete = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
                child: actualite.auteurPhoto == null
                    ? Text(
                        (actualite.auteurNom ?? '?').split(' ').first.isEmpty
                            ? '?'
                            : (actualite.auteurNom ?? '?').split(' ').first[0],
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      )
                    : ClipOval(
                        child: Image.memory(
                          base64Decode(actualite.auteurPhoto!),
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(actualite.auteurNom ?? 'Travel Platform',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                        if (actualite.auteurRole != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tealLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              Role.depuis(actualite.auteurRole!).libelle,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(dateCourte(actualite.datePublication),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grey)),
                  ],
                ),
              ),
              Pastille(libelle: actualite.categorie.libelle, valeur: 'valide'),
            ],
          ),
          const SizedBox(height: 4),
          Text(actualite.titre,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(complete ? actualite.contenu : FilActualites.extrait(actualite.contenu),
              maxLines: complete ? null : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.grey)),
        ],
      ),
    );
  }
}

/// Titre de section « À la une ........ Tout voir ».
class TitreSection extends StatelessWidget {
  final String titre;
  final VoidCallback? toutVoir;
  const TitreSection({super.key, required this.titre, this.toutVoir});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(titre,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        if (toutVoir != null)
          GestureDetector(
            onTap: toutVoir,
            child: const Text('Tout voir',
                style: TextStyle(
                    color: AppColors.orangeText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
