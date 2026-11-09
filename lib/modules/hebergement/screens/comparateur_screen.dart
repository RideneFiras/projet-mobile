import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/galerie_photos.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/hebergement.dart';
import 'hebergement_detail_screen.dart';

/// Comparaison côte à côte de 2 ou 3 établissements : une colonne par établissement,
/// une ligne par critère ; le meilleur prix et la meilleure note sont mis en valeur.
class ComparateurScreen extends StatelessWidget {
  final List<Hebergement> hebergements;

  const ComparateurScreen({super.key, required this.hebergements});

  @override
  Widget build(BuildContext context) {
    final liste = hebergements.take(3).toList();
    final prixMin = liste.map((h) => h.prixParNuit).reduce((a, b) => a < b ? a : b);
    final noteMax = liste.map((h) => h.noteMoyenne).reduce((a, b) => a > b ? a : b);

    final lignes = <(String, Widget Function(Hebergement))>[
      ('Type', (h) => Text(h.type.libelle)),
      ('Ville', (h) => Text(h.ville ?? '—')),
      ('Étoiles', (h) => Text(h.etoiles == null ? '—' : '★' * h.etoiles!)),
      (
        'Prix / nuit',
        (h) => Text(Montants.affiche(h.prixParNuit),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: h.prixParNuit == prixMin ? AppColors.teal : AppColors.navy)),
      ),
      (
        'Note',
        (h) => Text(h.nbAvis == 0 ? '—' : '${h.noteMoyenne.toStringAsFixed(1)} (${h.nbAvis})',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: h.nbAvis > 0 && h.noteMoyenne == noteMax
                    ? AppColors.teal
                    : AppColors.navy)),
      ),
      ('Capacité', (h) => Text('${h.capacite} pers. / chambre')),
      ('Chambres', (h) => Text('${h.nbChambres}')),
      ('Surface', (h) => Text(h.superficie == null ? '—' : '${h.superficie!.round()} m²')),
      ('Horaires', (h) => Text('${h.heureArrivee} → ${h.heureDepart}')),
      for (final e in Equipement.values)
        (
          e.libelle,
          (h) => Icon(h.possede(e) ? Icons.check_circle : Icons.remove,
              size: 20, color: h.possede(e) ? AppColors.teal : AppColors.border),
        ),
    ];

    return EcranModule(
      titre: 'Comparer',
      corps: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.1)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
              horizontalInside: BorderSide(color: AppColors.border, width: 0.8)),
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final h in liste)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: InkWell(
                      onTap: () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HebergementDetailScreen(hebergementId: h.id!)),
                      ),
                      child: Column(
                        children: [
                          PhotoModule(
                            source: h.photoPrincipale,
                            iconeParDefaut: h.type.icone,
                            hauteur: 70,
                            largeur: double.infinity,
                            rayon: 10,
                          ),
                          const SizedBox(height: 6),
                          Text(h.nom,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            for (final (libelle, cellule) in lignes)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(libelle,
                        style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  ),
                  for (final h in liste)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Center(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                          child: cellule(h),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
