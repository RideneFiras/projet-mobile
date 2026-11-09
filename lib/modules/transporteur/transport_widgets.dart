import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/ui_kit.dart' hide ChampDate;
import 'transport_ia.dart';

/// Écran de base du module : même style que les écrans d'accueil (UI Kit),
/// contenu limité à 640 px de large pour rester lisible sur tablette et PC.
class EcranTransport extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final IconData icone;
  final Widget child;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? boutonFlottant;

  const EcranTransport({
    super.key,
    required this.titre,
    required this.child,
    this.sousTitre,
    this.icone = Icons.local_shipping_outlined,
    this.actions,
    this.bottom,
    this.boutonFlottant,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(titre,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: boutonFlottant,
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                EnTeteModule(
                  titre: titre,
                  sousTitre: sousTitre ?? 'Commandes, trajets et mises en relation.',
                  icone: icone,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie à bordure fine ; cliquable si [onTap] est fourni.
class CarteTransport extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const CarteTransport({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// Pastille de statut. Les couleurs dépendent de la valeur stockée en base.
class BadgeStatut extends StatelessWidget {
  final String libelle;
  final String valeur;

  const BadgeStatut({super.key, required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    final (fond, texte) = switch (valeur) {
      'ouverte' || 'proposee' || 'en_attente' => (
          AppColors.orangeLight,
          AppColors.orangeText
        ),
      'acceptee' || 'confirmee' => (AppColors.tealLight, AppColors.teal),
      _ => (AppColors.disabled, AppColors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: fond, borderRadius: BorderRadius.circular(20)),
      child: Text(libelle,
          style: TextStyle(
              color: texte, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Ligne « Départ → Arrivée » en gras, utilisée dans toutes les cartes.
class LigneTrajet extends StatelessWidget {
  final String depart;
  final String arrivee;

  const LigneTrajet({super.key, required this.depart, required this.arrivee});

  @override
  Widget build(BuildContext context) {
    return Text('$depart → $arrivee',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
  }
}

/// Message quand une liste est vide.
class EtatVide extends StatelessWidget {
  final IconData icone;
  final String message;

  const EtatVide({super.key, required this.icone, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.tealLight, shape: BoxShape.circle),
              child: Icon(icone, size: 36, color: AppColors.teal),
            ),
            const SizedBox(height: 18),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 15)),
          ],
        ),
      ),
    );
  }
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

/// Indique si la réponse vient de l'assistant IA ou du calcul local.
class BandeauSource extends StatelessWidget {
  final SourceIa source;

  const BandeauSource({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final serveur = source == SourceIa.serveur;
    return Row(
      children: [
        Icon(serveur ? Icons.auto_awesome : Icons.offline_bolt_outlined,
            size: 15, color: AppColors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            serveur
                ? 'Réponse de l\'assistant IA'
                : 'Mode local : assistant IA indisponible',
            style: const TextStyle(color: AppColors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Champ de date dans le style des champs du UI Kit.
class ChampDate extends StatelessWidget {
  final String label;
  final DateTime? valeur;
  final ValueChanged<DateTime> onChoisie;
  final String? erreur;
  final DateTime? premiereDate;

  const ChampDate({
    super.key,
    required this.label,
    required this.valeur,
    required this.onChoisie,
    this.erreur,
    this.premiereDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            // Dates normalisées au jour : showDatePicker exige initialDate >= firstDate.
            final maintenant = DateUtils.dateOnly(DateTime.now());
            final premiere = premiereDate == null
                ? DateTime(maintenant.year - 1)
                : DateUtils.dateOnly(premiereDate!);
            var initiale =
                valeur == null ? maintenant : DateUtils.dateOnly(valeur!);
            if (initiale.isBefore(premiere)) initiale = premiere;
            final d = await showDatePicker(
              context: context,
              initialDate: initiale,
              firstDate: premiere,
              lastDate: DateTime(maintenant.year + 3),
            );
            if (d != null) onChoisie(d);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: erreur == null ? AppColors.border : AppColors.danger),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AppColors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(
                        valeur == null ? 'Choisir une date' : dateCourte(valeur!),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: valeur == null
                                ? const Color(0xFF8A97A5)
                                : AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(erreur!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
      ],
    );
  }
}

/// Snack-bar standard du module (messages d'erreur ou de confirmation).
void montrerMessage(BuildContext context, String texte) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte)));
}
