import '../../core/services/api_service.dart';
import '../../core/utils/dates.dart';
import 'models/commande_transport.dart';
import 'models/reservation_transport.dart';
import 'models/voyageur_candidat.dart';
import 'transport_format.dart';

/// Origine d'un résultat : affichée à l'utilisateur pour savoir qui a répondu.
enum SourceIa { serveur, local }

/// Commande interprétée à partir d'un texte libre (« de Tunis à Sfax demain budget 50 »).
class InterpretationCommande {
  final String? depart;
  final String? arrivee;
  final DateTime? date;
  final double? budget;
  final String description;
  final SourceIa source;

  const InterpretationCommande({
    this.depart,
    this.arrivee,
    this.date,
    this.budget,
    required this.description,
    required this.source,
  });
}

/// Score d'un voyageur pour une commande, avec la raison lisible.
class ScoreVoyageur {
  final VoyageurCandidat voyageur;
  final int score;
  final String raison;

  const ScoreVoyageur({
    required this.voyageur,
    required this.score,
    required this.raison,
  });
}

/// Fonctionnalités IA du module :
///  1. interpréter une commande en texte libre ;
///  2. classer les voyageurs pour une commande ;
///  3. rédiger le résumé d'un trajet.
///
/// Règles du cahier des charges : l'appel au modèle passe toujours par le
/// serveur applicatif (jamais depuis l'application), l'IA ne décide ni les prix
/// ni les accès, et une réponse absente ou invalide bascule sur la version locale.
class TransportIa {
  TransportIa._();

  static const String _interpreter = '/transport/interpreter-commande';
  static const String _classer = '/transport/classer-voyageurs';
  static const String _resumer = '/transport/resumer-trajet';

  // ------------------------------------------------------------------
  // 1. Interprétation d'une commande
  // ------------------------------------------------------------------

  static Future<InterpretationCommande> interpreterCommande(
      String texte, {DateTime? maintenant}) async {
    final ici = maintenant ?? DateTime.now();
    try {
      final rep = await ApiService.instance
          .post(_interpreter, {'texte': texte, 'date_reference': ici.toIso8601String()});
      if (rep is Map<String, dynamic>) {
        final depart = rep['depart'] as String?;
        final arrivee = rep['arrivee'] as String?;
        if (depart != null && arrivee != null && depart.trim().isNotEmpty) {
          return InterpretationCommande(
            depart: depart.trim(),
            arrivee: arrivee.trim(),
            date: DateTime.tryParse((rep['date'] as String?) ?? ''),
            budget: (rep['budget'] as num?)?.toDouble(),
            description: texte.trim(),
            source: SourceIa.serveur,
          );
        }
      }
    } on Exception catch (_) {
      // Serveur indisponible : on bascule sur la version locale.
    }
    return interpreterLocal(texte, maintenant: ici);
  }

  /// Version locale, sans réseau : reconnaît « de X à Y », « demain »,
  /// une date jj/mm, et un budget suivi de DT / TND.
  static InterpretationCommande interpreterLocal(String texte,
      {DateTime? maintenant}) {
    final ici = maintenant ?? DateTime.now();
    final t = texte.trim();
    String? depart;
    String? arrivee;

    final trajet = RegExp(r'\bde\s+(.+?)\s+(?:à|a|vers)\s+(.+)',
            caseSensitive: false, unicode: true)
        .firstMatch(t);
    if (trajet != null) {
      depart = _premierMot(trajet.group(1)!);
      arrivee = _premierMot(trajet.group(2)!);
    }

    DateTime? date;
    final jour = DateTime(ici.year, ici.month, ici.day);
    if (RegExp(r'\bdemain\b', caseSensitive: false).hasMatch(t)) {
      date = jour.add(const Duration(days: 1));
    } else if (RegExp('aujourd', caseSensitive: false).hasMatch(t)) {
      date = jour;
    } else {
      final d = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?').firstMatch(t);
      if (d != null) {
        date = DateTime(
          int.tryParse(d.group(3) ?? '') ?? ici.year,
          int.parse(d.group(2)!),
          int.parse(d.group(1)!),
        );
      }
    }

    double? budget;
    final b = RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(?:dt|tnd|dinars?)',
            caseSensitive: false)
        .firstMatch(t);
    if (b != null) {
      final c = TransportFormat.parserMontant(b.group(1));
      if (c != null) budget = TransportFormat.depuisCentimes(c);
    }

    return InterpretationCommande(
      depart: depart,
      arrivee: arrivee,
      date: date,
      budget: budget,
      description: t,
      source: SourceIa.local,
    );
  }

  /// Coupe « Sfax demain budget 50 » en « Sfax ».
  static String _premierMot(String s) => s
      .split(RegExp(r'\s+(?:le|demain|budget|pour|avec|dans)\b',
          caseSensitive: false))
      .first
      .replaceAll(RegExp(r'[,.;!?]+$'), '')
      .trim();

  // ------------------------------------------------------------------
  // 2. Classement des voyageurs
  // ------------------------------------------------------------------

  static Future<List<ScoreVoyageur>> classerVoyageurs(
    CommandeTransport commande,
    List<VoyageurCandidat> candidats,
  ) async {
    if (candidats.isEmpty) return const [];
    try {
      final rep = await ApiService.instance.post(_classer, {
        'depart': commande.depart,
        'arrivee': commande.arrivee,
        'date': ReservationTransport.dateIso(commande.dateSouhaitee),
        'candidats': [
          for (final v in candidats)
            {
              'id': v.id,
              'voyages': [
                for (final t in v.voyages)
                  {
                    'destination': t.destination,
                    'date_debut': ReservationTransport.dateIso(t.dateDebut),
                    'date_fin': ReservationTransport.dateIso(t.dateFin),
                  }
              ],
            }
        ],
      });
      if (rep is List) {
        final parId = {for (final v in candidats) v.id: v};
        final scores = <ScoreVoyageur>[];
        for (final e in rep) {
          if (e is! Map) continue;
          final id = e['voyageur_id'];
          final v = id is int ? parId[id] : null;
          if (v == null) continue; // l'IA ne peut pas inventer un voyageur
          final brut = ((e['score'] as num?) ?? 0).round();
          final score = brut < 0 ? 0 : (brut > 100 ? 100 : brut);
          scores.add(ScoreVoyageur(
            voyageur: v,
            score: score,
            raison: (e['raison'] as String?) ?? 'Classé par l\'assistant',
          ));
        }
        if (scores.isNotEmpty) {
          scores.sort((a, b) => b.score.compareTo(a.score));
          return scores;
        }
      }
    } on Exception catch (_) {
      // Repli local ci-dessous.
    }
    return classerLocal(commande, candidats);
  }

  /// Score local : destination = arrivée (+50), date souhaitée dans le voyage
  /// à 3 jours près (+30), voyage à venir (+20).
  static List<ScoreVoyageur> classerLocal(
    CommandeTransport commande,
    List<VoyageurCandidat> candidats,
  ) {
    final scores = <ScoreVoyageur>[];
    final marge = const Duration(days: 3);
    final date = commande.dateSouhaitee;
    for (final v in candidats) {
      var meilleur = 0;
      var raison = 'Aucun voyage déclaré';
      for (final t in v.voyages) {
        var s = 0;
        final motifs = <String>[];
        if (TransportFormat.memeVille(t.destination, commande.arrivee)) {
          s += 50;
          motifs.add('va à ${commande.arrivee}');
        }
        final debut = t.dateDebut.subtract(marge);
        final fin = t.dateFin.add(marge);
        if (!date.isBefore(debut) && !date.isAfter(fin)) {
          s += 30;
          motifs.add('voyage à la bonne date');
        }
        if (t.dateDebut.isAfter(DateTime.now())) {
          s += 20;
          motifs.add('voyage à venir');
        }
        if (s > meilleur) {
          meilleur = s;
          raison = motifs.isEmpty ? 'Voyage déclaré' : motifs.join(', ');
        }
      }
      scores.add(ScoreVoyageur(voyageur: v, score: meilleur, raison: raison));
    }
    scores.sort((a, b) => b.score.compareTo(a.score) != 0
        ? b.score.compareTo(a.score)
        : a.voyageur.nom.compareTo(b.voyageur.nom));
    return scores;
  }

  // ------------------------------------------------------------------
  // 3. Résumé d'un trajet
  // ------------------------------------------------------------------

  static Future<({String texte, SourceIa source})> resumerTrajet(
      ReservationTransport r) async {
    try {
      final rep = await ApiService.instance.post(_resumer, {
        'depart': r.depart,
        'arrivee': r.arrivee,
        'date': ReservationTransport.dateIso(r.dateDepart),
        'prix': r.prix,
        'statut': r.statut.valeur,
        'transporteur': r.nomTransporteur,
      });
      if (rep is Map && rep['resume'] is String) {
        return (texte: rep['resume'] as String, source: SourceIa.serveur);
      }
    } on Exception catch (_) {
      // Repli local ci-dessous.
    }
    return (texte: resumerLocal(r), source: SourceIa.local);
  }

  static String resumerLocal(ReservationTransport r) {
    final transporteur = r.nomTransporteur ?? 'transporteur non précisé';
    return 'Trajet ${r.depart} → ${r.arrivee}, le ${dateCourte(r.dateDepart)}, '
        'assuré par $transporteur, pour ${TransportFormat.prix(r.prix)}. '
        'Statut : ${r.statut.libelle}.';
  }
}
