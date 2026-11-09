import 'dart:typed_data';

import '../../core/utils/dates.dart';
import '../../core/utils/pdf_simple.dart';
import 'models/location_vehicule.dart';
import 'models/vehicule.dart';

/// Trait de signature, points normalisés entre 0 et 1 dans la zone de signature.
typedef TraitSignature = List<(double, double)>;

/// Contrat de location au format PDF (générateur maison, sans package).
class ContratLocation {
  ContratLocation._();

  /// Construit le PDF du contrat. [signature] vide = cadre de signature laissé blanc.
  static Uint8List genererPdf({
    required LocationVehicule location,
    required Vehicule vehicule,
    required String nomClient,
    String? emailClient,
    List<TraitSignature> signature = const [],
    DateTime? signeLe,
  }) {
    final pdf = DocumentPdf();
    const gauche = 56.0;
    var y = 64.0;

    pdf.texte(gauche, y, 'CONTRAT DE LOCATION DE VÉHICULE', taille: 18, gras: true);
    y += 22;
    pdf.texte(gauche, y,
        'Travel Platform · Contrat n° LV-${location.id ?? 0} · édité le ${_date(DateTime.now())}',
        taille: 10);
    y += 14;
    pdf.trait(gauche, y, DocumentPdf.largeur - gauche, y);
    y += 24;

    y = _section(pdf, y, 'Parties');
    y = _ligne(pdf, y, 'Loueur', 'Travel Platform — agence de location');
    y = _ligne(pdf, y, 'Locataire', nomClient);
    if (emailClient != null) y = _ligne(pdf, y, 'E-mail', emailClient);
    if (location.numeroPermis != null) y = _ligne(pdf, y, 'Permis n°', location.numeroPermis!);

    y = _section(pdf, y + 8, 'Véhicule');
    y = _ligne(pdf, y, 'Désignation', '${vehicule.type.libelle} ${vehicule.nom}');
    if (vehicule.immatriculation != null) {
      y = _ligne(pdf, y, 'Immatriculation', vehicule.immatriculation!);
    }
    y = _ligne(pdf, y, 'Caractéristiques', vehicule.resumeTechnique);
    if (vehicule.kilometrage != null) {
      y = _ligne(pdf, y, 'Kilométrage au départ', '${vehicule.kilometrage} km');
    }

    y = _section(pdf, y + 8, 'Période et lieux');
    y = _ligne(pdf, y, 'Du', _date(location.dateDebut));
    y = _ligne(pdf, y, 'Au', '${_date(location.dateFin)} (${location.jours} jour'
        '${location.jours > 1 ? 's' : ''})');
    y = _ligne(pdf, y, 'Prise en charge', location.lieuPrise ?? 'À l\'agence');
    y = _ligne(pdf, y, 'Retour', location.lieuRetour ?? location.lieuPrise ?? 'À l\'agence');

    y = _section(pdf, y + 8, 'Prix');
    if (location.options.isNotEmpty) {
      y = _ligne(pdf, y, 'Options', location.options.map((o) => o.libelle).join(', '));
    }
    y = _ligne(pdf, y, 'Prix total', _montant(location.prixTotal));
    y = _ligne(pdf, y, 'Caution', '${_montant(location.caution)} (restituée au retour)');

    y = _section(pdf, y + 8, 'Conditions');
    for (final c in [
      'Le véhicule est rendu à la date prévue, au lieu convenu, dans l\'état constaté au départ.',
      'Tout jour de retard est facturé ${LocationVehicule.coefficientRetard} fois le prix '
          'journalier (${_montant(vehicule.prixParJour * LocationVehicule.coefficientRetard)} '
          'par jour).',
      'Le locataire est responsable des amendes et péages pendant la location.',
      'La caution peut être retenue en cas de dommage constaté au retour.',
    ]) {
      y = pdf.paragraphe(gauche, y, '• $c', taille: 10, largeurMax: 480);
    }

    // Signature du locataire.
    y += 16;
    pdf.texte(gauche, y, 'Signature du locataire', taille: 11, gras: true);
    if (signeLe != null) {
      pdf.texte(gauche + 260, y, 'Signé électroniquement le ${_date(signeLe)}', taille: 10);
    }
    y += 8;
    const largeurCadre = 240.0;
    const hauteurCadre = 90.0;
    pdf.rectangle(gauche, y, largeurCadre, hauteurCadre);
    for (final trait in signature) {
      pdf.polyligne([
        for (final (px, py) in trait)
          (gauche + 6 + px.clamp(0.0, 1.0) * (largeurCadre - 12),
              y + 6 + py.clamp(0.0, 1.0) * (hauteurCadre - 12)),
      ]);
    }
    return pdf.enOctets();
  }

  static double _section(DocumentPdf pdf, double y, String titre) {
    pdf.texte(56, y, titre.toUpperCase(), taille: 11, gras: true);
    return y + 18;
  }

  static double _ligne(DocumentPdf pdf, double y, String libelle, String valeur) {
    pdf.texte(56, y, libelle, taille: 10);
    return pdf.paragraphe(200, y, valeur, taille: 10, largeurMax: 330);
  }

  static String _date(DateTime d) => dateCourte(d);

  static String _montant(double v) => '${v.toStringAsFixed(2)} DT';
}
