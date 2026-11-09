import 'dart:convert';
import 'dart:typed_data';

/// Générateur PDF minimal, sans package : pages A4, texte (Helvetica / Helvetica-Bold,
/// encodage WinAnsi pour les accents français), traits (signature, séparateurs).
/// Coordonnées en points, origine en HAUT à gauche (convertie pour le PDF).
class DocumentPdf {
  static const double largeur = 595.28;
  static const double hauteur = 841.89;

  final List<StringBuffer> _pages = [];

  DocumentPdf() {
    nouvellePage();
  }

  StringBuffer get _page => _pages.last;

  void nouvellePage() => _pages.add(StringBuffer());

  int get nombrePages => _pages.length;

  /// Texte sur une ligne à la position (x, y) — y depuis le haut de la page.
  void texte(double x, double y, String contenu, {double taille = 11, bool gras = false}) {
    final police = gras ? 'F2' : 'F1';
    _page
      ..write('BT /$police ${_n(taille)} Tf ${_n(x)} ${_n(hauteur - y)} Td (')
      ..write(_echapper(contenu))
      ..write(') Tj ET\n');
  }

  /// Paragraphe coupé automatiquement ; renvoie la position y après le dernier trait.
  double paragraphe(double x, double y, String contenu,
      {double taille = 11, double largeurMax = 480, bool gras = false}) {
    // Largeur moyenne d'un caractère Helvetica ≈ 0,5 x taille.
    final maxCaracteres = (largeurMax / (taille * 0.5)).floor();
    var ligne = '';
    var yCourant = y;
    for (final mot in contenu.split(RegExp(r'\s+'))) {
      if (mot.isEmpty) continue;
      final essai = ligne.isEmpty ? mot : '$ligne $mot';
      if (essai.length > maxCaracteres && ligne.isNotEmpty) {
        texte(x, yCourant, ligne, taille: taille, gras: gras);
        yCourant += taille * 1.4;
        ligne = mot;
      } else {
        ligne = essai;
      }
    }
    if (ligne.isNotEmpty) {
      texte(x, yCourant, ligne, taille: taille, gras: gras);
      yCourant += taille * 1.4;
    }
    return yCourant;
  }

  /// Trait droit.
  void trait(double x1, double y1, double x2, double y2, {double epaisseur = 1}) {
    _page.write('${_n(epaisseur)} w ${_n(x1)} ${_n(hauteur - y1)} m '
        '${_n(x2)} ${_n(hauteur - y2)} l S\n');
  }

  /// Ligne brisée (un trait de signature).
  void polyligne(List<(double, double)> points, {double epaisseur = 1.5}) {
    if (points.length < 2) return;
    final b = StringBuffer('${_n(epaisseur)} w 1 J 1 j ');
    b.write('${_n(points.first.$1)} ${_n(hauteur - points.first.$2)} m ');
    for (final p in points.skip(1)) {
      b.write('${_n(p.$1)} ${_n(hauteur - p.$2)} l ');
    }
    b.write('S\n');
    _page.write(b);
  }

  /// Rectangle (cadre).
  void rectangle(double x, double y, double l, double h, {double epaisseur = 0.8}) {
    _page.write('${_n(epaisseur)} w ${_n(x)} ${_n(hauteur - y - h)} ${_n(l)} ${_n(h)} re S\n');
  }

  /// Octets du fichier PDF 1.4.
  Uint8List enOctets() {
    final objets = <List<int>>[];
    int ajouter(List<int> contenu) {
      objets.add(contenu);
      return objets.length;
    }

    List<int> latin(String s) => latin1.encode(s);

    final catalogue = ajouter(const []); // rempli plus bas (dépend de l'objet pages)
    final pagesId = ajouter(const []);
    final f1 = ajouter(latin('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>'));
    final f2 = ajouter(latin('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold '
        '/Encoding /WinAnsiEncoding >>'));
    final idsPages = <int>[];
    for (final p in _pages) {
      final flux = _winAnsi(p.toString());
      final contenu = ajouter([
        ...latin('<< /Length ${flux.length} >>\nstream\n'),
        ...flux,
        ...latin('\nendstream'),
      ]);
      idsPages.add(ajouter(latin('<< /Type /Page /Parent $pagesId 0 R '
          '/MediaBox [0 0 ${_n(largeur)} ${_n(hauteur)}] '
          '/Resources << /Font << /F1 $f1 0 R /F2 $f2 0 R >> >> '
          '/Contents $contenu 0 R >>')));
    }
    objets[catalogue - 1] = latin('<< /Type /Catalog /Pages $pagesId 0 R >>');
    objets[pagesId - 1] = latin('<< /Type /Pages /Kids [${idsPages.map((i) => '$i 0 R').join(' ')}] '
        '/Count ${idsPages.length} >>');

    final sortie = BytesBuilder();
    sortie.add(latin('%PDF-1.4\n'));
    sortie.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]); // marqueur binaire
    final positions = <int>[];
    for (var i = 0; i < objets.length; i++) {
      positions.add(sortie.length);
      sortie.add(latin('${i + 1} 0 obj\n'));
      sortie.add(objets[i]);
      sortie.add(latin('\nendobj\n'));
    }
    final debutXref = sortie.length;
    final xref = StringBuffer('xref\n0 ${objets.length + 1}\n0000000000 65535 f \n');
    for (final p in positions) {
      xref.write('${p.toString().padLeft(10, '0')} 00000 n \n');
    }
    sortie.add(latin(xref.toString()));
    sortie.add(latin('trailer\n<< /Size ${objets.length + 1} /Root $catalogue 0 R >>\n'
        'startxref\n$debutXref\n%%EOF\n'));
    return sortie.toBytes();
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _echapper(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  /// Caractères hors Latin-1 convertis vers WinAnsi (€, guillemets, tirets…) ou « ? ».
  static List<int> _winAnsi(String s) {
    const speciaux = {
      '€': 0x80, '‚': 0x82, '„': 0x84, '…': 0x85, '‘': 0x91, '’': 0x92, '“': 0x93,
      '”': 0x94, '•': 0x95, '–': 0x96, '—': 0x97, 'œ': 0x9C, 'Œ': 0x8C, 'Ÿ': 0x9F,
    };
    final octets = <int>[];
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      if (r < 0x80 || (r >= 0xA0 && r <= 0xFF)) {
        octets.add(r);
      } else if (speciaux.containsKey(c)) {
        octets.add(speciaux[c]!);
      } else if (r == 0x2192) {
        octets.addAll('->'.codeUnits); // flèche
      } else {
        octets.add(0x3F); // ?
      }
    }
    return octets;
  }
}
