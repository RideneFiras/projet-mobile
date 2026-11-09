import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/dates.dart';

/// Composants partagés par tous les modules : même langage visuel que le UI Kit
/// (dégradé teal, cartes blanches à bordure fine, pastilles, champs arrondis).

/// Couleurs (fond, texte) d'une pastille, selon la valeur stockée en base.
(Color, Color) couleursStatut(String valeur) => switch (valeur) {
      'planifie' || 'ouverte' || 'proposee' || 'en_attente' || 'loue' ||
      'maintenance' || 'travaux' =>
        (AppColors.orangeLight, AppColors.orangeText),
      'actif' || 'acceptee' || 'confirmee' || 'disponible' || 'valide' ||
      'en_cours' || 'check_in' =>
        (AppColors.tealLight, AppColors.teal),
      'refusee' || 'annule' || 'annulee' || 'indisponible' || 'hors_service' ||
      'ferme' =>
        (const Color(0xFFFBE3E0), AppColors.danger),
      _ => (AppColors.disabled, AppColors.grey),
    };

/// Pastille de statut : la couleur dépend de [valeur], le texte affiché est [libelle].
class Pastille extends StatelessWidget {
  final String libelle;
  final String valeur;

  const Pastille({super.key, required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    final (fond, texte) = couleursStatut(valeur);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(20)),
      child: Text(libelle,
          style: TextStyle(color: texte, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// En-tête coloré en haut d'un écran de module, avec indicateurs optionnels.
class EnTeteModule extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final List<IndicateurEnTete> indicateurs;

  const EnTeteModule({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icone,
    this.indicateurs = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        decoration: const BoxDecoration(color: AppColors.teal),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(icone, color: AppColors.orange, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titre,
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(sousTitre,
                              style: const TextStyle(
                                  color: Color(0xE6FFFFFF), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (indicateurs.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: indicateurs),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// Petit indicateur chiffré dans l'en-tête (ex : « 3 voyages »).
class IndicateurEnTete extends StatelessWidget {
  final String valeur;
  final String libelle;
  final IconData icone;

  const IndicateurEnTete({
    super.key,
    required this.valeur,
    required this.libelle,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: AppColors.white, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valeur,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text(libelle,
                  style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte blanche arrondie, cliquable si [onTap] est fourni.
/// [accent] ajoute une barre de couleur à gauche (ex : statut).
class CarteModule extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;

  const CarteModule({super.key, required this.child, this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final contenu = Padding(padding: const EdgeInsets.all(16), child: child);
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: accent == null
            ? contenu
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: accent),
                    Expanded(child: contenu),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Titre de section (« Mes voyages », « Véhicules »…) avec action optionnelle à droite.
class EnteteSection extends StatelessWidget {
  final String titre;
  final Widget? action;

  const EnteteSection({super.key, required this.titre, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(titre,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Décoration commune des champs : fond blanc, bordure arrondie, focus teal.
InputDecoration decorationUi(String label, {IconData? icone}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.grey),
      prefixIcon: icone == null ? null : Icon(icone, color: AppColors.grey),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _bordure(AppColors.border),
      enabledBorder: _bordure(AppColors.border),
      focusedBorder: _bordure(AppColors.teal, epaisseur: 1.6),
      errorBorder: _bordure(AppColors.danger),
      focusedErrorBorder: _bordure(AppColors.danger, epaisseur: 1.6),
    );

OutlineInputBorder _bordure(Color couleur, {double epaisseur = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: couleur, width: epaisseur),
    );

/// Champ texte avec validation (Form).
class ChampTexte extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icone;
  final TextInputType? clavier;
  final String? Function(String?)? validateur;
  final int lignes;
  final TextCapitalization capitalisation;

  const ChampTexte({
    super.key,
    required this.controller,
    required this.label,
    this.icone,
    this.clavier,
    this.validateur,
    this.lignes = 1,
    this.capitalisation = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: clavier,
      validator: validateur,
      minLines: lignes,
      maxLines: lignes,
      textCapitalization: capitalisation,
      decoration: decorationUi(label, icone: icone),
    );
  }
}

/// Liste déroulante dans le style des champs. [erreur] s'affiche sous le champ.
class ChampChoix<T> extends StatelessWidget {
  final String label;
  final IconData? icone;
  final T? valeur;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChange;
  final String? erreur;

  const ChampChoix({
    super.key,
    required this.label,
    required this.items,
    required this.onChange,
    this.valeur,
    this.icone,
    this.erreur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: erreur == null ? AppColors.border : AppColors.danger),
          ),
          child: Row(
            children: [
              if (icone != null) ...[
                Icon(icone, color: AppColors.grey),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: valeur,
                    isExpanded: true,
                    hint: Text(label, style: const TextStyle(color: AppColors.grey)),
                    items: items,
                    onChanged: onChange,
                  ),
                ),
              ),
            ],
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

/// Sélecteur de date dans le style des champs. Dates normalisées au jour.
class ChampDate extends StatelessWidget {
  final String label;
  final DateTime? valeur;
  final ValueChanged<DateTime> onChoisie;
  final String? erreur;
  final DateTime? premiereDate;
  final DateTime? derniereDate;

  const ChampDate({
    super.key,
    required this.label,
    required this.valeur,
    required this.onChoisie,
    this.erreur,
    this.premiereDate,
    this.derniereDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final aujourdhui = dateJour(DateTime.now());
            final premiere = premiereDate == null
                ? DateTime(aujourdhui.year - 5)
                : dateJour(premiereDate!);
            final derniere = derniereDate == null
                ? DateTime(aujourdhui.year + 5)
                : dateJour(derniereDate!);
            var initiale = dateJour(valeur ?? aujourdhui);
            if (initiale.isBefore(premiere)) initiale = premiere;
            if (initiale.isAfter(derniere)) initiale = derniere;
            final d = await showDatePicker(
              context: context,
              initialDate: initiale,
              firstDate: premiere,
              lastDate: derniere,
            );
            if (d != null) onChoisie(dateJour(d));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: erreur == null ? AppColors.border : AppColors.danger),
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
                              fontSize: 13,
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

/// Bouton principal teal en pilule (56 px de haut, pleine largeur par défaut).
class BoutonPrincipal extends StatelessWidget {
  final String libelle;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool pleineLargeur;

  const BoutonPrincipal({
    super.key,
    required this.libelle,
    this.onPressed,
    this.icone,
    this.pleineLargeur = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.teal,
      foregroundColor: AppColors.white,
      disabledBackgroundColor: AppColors.disabled,
      minimumSize: const Size(0, 54),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    final bouton = icone == null
        ? FilledButton(onPressed: onPressed, style: style, child: Text(libelle))
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icone, size: 20),
            label: Text(libelle),
          );
    return pleineLargeur ? SizedBox(width: double.infinity, child: bouton) : bouton;
  }
}

/// Bouton secondaire (contour teal), pour « Annuler » ou une action alternative.
class BoutonSecondaire extends StatelessWidget {
  final String libelle;
  final VoidCallback? onPressed;
  final IconData? icone;

  const BoutonSecondaire({super.key, required this.libelle, this.onPressed, this.icone});

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.teal,
      minimumSize: const Size(0, 54),
      side: const BorderSide(color: AppColors.teal, width: 1.4),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    final bouton = icone == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(libelle))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icone, size: 20),
            label: Text(libelle),
          );
    return SizedBox(width: double.infinity, child: bouton);
  }
}

/// Écran standard d'un module : barre fine + contenu centré (max 720 px).
class EcranModule extends StatelessWidget {
  final String titre;
  final Widget corps;
  final List<Widget>? actions;
  final Widget? boutonFlottant;

  const EcranModule({
    super.key,
    required this.titre,
    required this.corps,
    this.actions,
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
      ),
      floatingActionButton: boutonFlottant,
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: corps,
          ),
        ),
      ),
    );
  }
}

/// Grille responsive sans hauteur fixe : 1 colonne sur téléphone, 2 ou 3 sur tablette/PC.
class GrilleAdaptative extends StatelessWidget {
  final List<Widget> enfants;
  final double largeurMin;
  final double espacement;

  const GrilleAdaptative({
    super.key,
    required this.enfants,
    this.largeurMin = 300,
    this.espacement = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final colonnes = (c.maxWidth / largeurMin).floor().clamp(1, 3).toInt();
        final largeur = (c.maxWidth - espacement * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: espacement,
          runSpacing: espacement,
          children: [
            for (final e in enfants) SizedBox(width: largeur, child: e),
          ],
        );
      },
    );
  }
}

/// État vide illustré, avec bouton d'action optionnel.
class EtatVideModule extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String message;
  final String? libelleAction;
  final VoidCallback? onAction;

  const EtatVideModule({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
    this.libelleAction,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
                color: AppColors.tealLight, shape: BoxShape.circle),
            child: Icon(icone, size: 38, color: AppColors.teal),
          ),
          const SizedBox(height: 18),
          Text(titre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          if (libelleAction != null && onAction != null) ...[
            const SizedBox(height: 20),
            BoutonPrincipal(
              libelle: libelleAction!,
              onPressed: onAction,
              pleineLargeur: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Boîte de confirmation avant suppression (true = confirmé).
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String action = 'Supprimer',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Message rapide en bas d'écran (vert teal = succès, rouge = erreur).
void afficherMessage(BuildContext context, String texte, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? AppColors.danger : AppColors.teal,
    ));
}
