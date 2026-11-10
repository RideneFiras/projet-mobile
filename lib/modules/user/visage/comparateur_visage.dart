import 'dart:convert';
import 'dart:math';

/// Compare deux « empreintes » de visage (vecteurs de 128 nombres produits
/// par le réseau de reconnaissance faciale, voir web/face_auth.js).
///
/// Même principe que la librairie Python face_recognition : deux photos de
/// la même personne donnent des vecteurs proches (distance euclidienne
/// faible), deux personnes différentes des vecteurs éloignés.
class ComparateurVisage {
  ComparateurVisage._();

  /// Taille d'un descripteur de visage.
  static const int taille = 128;

  /// Distance maximale pour considérer que c'est la même personne.
  /// 0.6 est la valeur usuelle ; 0.5 est plus strict (moins de faux positifs).
  static const double seuil = 0.5;

  static double distance(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Descripteurs de tailles différentes');
    }
    var somme = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      somme += d * d;
    }
    return sqrt(somme);
  }

  static bool correspond(List<double> reference, List<double> capture) =>
      distance(reference, capture) <= seuil;

  static bool estValide(List<double> d) =>
      d.length == taille && d.every((x) => x.isFinite);

  static String encoder(List<double> d) => jsonEncode(d);

  static List<double> decoder(String texte) => (jsonDecode(texte) as List)
      .map((x) => (x as num).toDouble())
      .toList(growable: false);
}
