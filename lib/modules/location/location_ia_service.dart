import 'dart:convert';

import '../../core/services/gemini_service.dart';
import '../../core/services/hugging_face_service.dart';
import 'models/filtres_vehicule.dart';
import 'models/vehicule.dart';

/// Message d'une conversation avec l'assistant (rôle « client » ou « assistant »).
typedef MessageAssistant = ({bool deClient, String texte});

/// Fonctions d'IA du module location (Google Gemini) :
/// texte libre -> filtres, recommandation, description, résumé d'avis, prix, chatbot.
/// Sans clé ou hors connexion, les fonctions qui le peuvent basculent sur une
/// version locale (règles simples) : l'application reste utilisable.
class LocationIaService {
  final GeminiService _gemini;

  LocationIaService({GeminiService? gemini}) : _gemini = gemini ?? GeminiService();

  bool get configure => _gemini.configure;

  // ------------------------------------------------------------------
  // 1. Texte libre -> filtres
  // ------------------------------------------------------------------

  /// « Voiture familiale électrique, 80 DT par jour max » -> filtres.
  /// [parIa] = false si l'analyse locale a été utilisée.
  Future<({FiltresVehicule filtres, bool parIa})> analyserDemande(String texte) async {
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu transformes une demande de location de véhicule en filtres. '
              'Réponds UNIQUEMENT en JSON : {"type": "voiture"|"moto"|"bicyclette"|null, '
              '"prix_max": nombre|null, "places_min": entier|null, '
              '"carburant": "essence"|"diesel"|"electrique"|"hybride"|"aucun"|null, '
              '"boite": "manuelle"|"automatique"|null, "annee_min": entier|null}. '
              'Une famille = 5 places. Les prix sont en dinars tunisiens par jour.',
          demande: texte,
        );
        if (json is Map) return (filtres: filtresDepuisJson(json), parIa: true);
      } on IaException {
        // Repli local ci-dessous.
      }
    }
    return (filtres: analyseLocale(texte), parIa: false);
  }

  /// Conversion du JSON de l'IA en filtres (valeurs inconnues ignorées).
  static FiltresVehicule filtresDepuisJson(Map json) {
    T? choix<T>(List<T> valeurs, String Function(T) cle, Object? v) {
      for (final x in valeurs) {
        if (cle(x) == v) return x;
      }
      return null;
    }

    final prix = json['prix_max'];
    final places = json['places_min'];
    final annee = json['annee_min'];
    return FiltresVehicule(
      type: choix(TypeVehicule.values, (t) => t.valeur, json['type']),
      prixMax: prix is num && prix > 0 ? prix.toDouble() : null,
      placesMin: places is num && places > 0 ? places.toInt() : null,
      carburant: choix(Carburant.values, (c) => c.valeur, json['carburant']),
      boite: choix(Boite.values, (b) => b.valeur, json['boite']),
      anneeMin: annee is num && annee > 1950 ? annee.toInt() : null,
    );
  }

  /// Analyse par mots-clés, sans réseau.
  static FiltresVehicule analyseLocale(String texte) {
    final t = texte.toLowerCase();
    bool contient(List<String> mots) => mots.any(t.contains);

    TypeVehicule? type;
    if (contient(['vélo', 'velo', 'bicyclette', 'vtt'])) {
      type = TypeVehicule.bicyclette;
    } else if (contient(['moto', 'scooter', 'deux-roues', 'deux roues'])) {
      type = TypeVehicule.moto;
    } else if (contient(['voiture', 'auto', 'suv', 'citadine', 'berline', 'familiale'])) {
      type = TypeVehicule.voiture;
    }

    Carburant? carburant;
    if (contient(['électrique', 'electrique'])) {
      carburant = Carburant.electrique;
    } else if (contient(['hybride'])) {
      carburant = Carburant.hybride;
    } else if (contient(['diesel', 'gasoil'])) {
      carburant = Carburant.diesel;
    } else if (contient(['essence'])) {
      carburant = Carburant.essence;
    }

    final budget = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:dt|tnd|dinars?|d\b)').firstMatch(t) ??
        RegExp(r'(?:budget|max(?:imum)?|moins de)\s*:?\s*(\d+(?:[.,]\d+)?)').firstMatch(t);
    final personnes = RegExp(r'(\d+)\s*(?:personnes?|pers\b|places?|adultes?)').firstMatch(t);
    int? placesMin = personnes == null ? null : int.tryParse(personnes.group(1)!);
    if (placesMin == null && contient(['famille', 'familiale', 'enfants'])) placesMin = 5;

    return FiltresVehicule(
      type: type,
      carburant: carburant,
      boite: contient(['automatique', 'boîte auto', 'boite auto']) ? Boite.automatique : null,
      prixMax: budget == null ? null : double.tryParse(budget.group(1)!.replaceAll(',', '.')),
      placesMin: placesMin,
      tri: contient(['pas cher', 'moins cher', 'économique', 'economique'])
          ? TriVehicule.prixCroissant
          : TriVehicule.nom,
    );
  }

  // ------------------------------------------------------------------
  // 2. Recommandation parmi les véhicules réels
  // ------------------------------------------------------------------

  /// Choisit au plus 3 véhicules de [candidats] pour la demande, avec une raison.
  /// Seuls des identifiants existants sont renvoyés.
  Future<List<({int vehiculeId, String raison})>> recommander(
      String demande, List<Vehicule> candidats) async {
    if (candidats.isEmpty) return const [];
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu es conseiller dans une agence de location en Tunisie. Choisis au plus '
              '3 véhicules de la liste fournie qui répondent le mieux à la demande. '
              'Réponds UNIQUEMENT en JSON : [{"id": entier, "raison": "phrase courte"}]. '
              'N\'invente aucun véhicule : utilise seulement les id de la liste.',
          demande: 'Demande : $demande\nVéhicules : ${jsonEncode(_resume(candidats))}',
        );
        final ids = {for (final v in candidats) v.id};
        if (json is List) {
          final choix = [
            for (final e in json)
              if (e is Map && e['id'] is num && ids.contains((e['id'] as num).toInt()))
                (vehiculeId: (e['id'] as num).toInt(), raison: '${e['raison'] ?? ''}'),
          ];
          if (choix.isNotEmpty) return choix.take(3).toList();
        }
      } on IaException {
        // Repli local.
      }
    }
    return recommandationLocale(analyseLocale(demande), candidats);
  }

  /// Score simple : critères respectés, puis note et prix.
  static List<({int vehiculeId, String raison})> recommandationLocale(
      FiltresVehicule f, List<Vehicule> candidats) {
    int score(Vehicule v) {
      var s = 0;
      if (f.type == null || v.type == f.type) s += 3;
      if (f.carburant == null || v.carburant == f.carburant) s += 2;
      if (f.prixMax == null || v.prixParJour <= f.prixMax!) s += 2;
      if (f.placesMin == null || v.places >= f.placesMin!) s += 2;
      if (f.boite == null || v.boite == f.boite) s += 1;
      return s;
    }

    final tries = [...candidats.where((v) => v.disponible)]
      ..sort((a, b) {
        final c = score(b).compareTo(score(a));
        if (c != 0) return c;
        final n = b.noteMoyenne.compareTo(a.noteMoyenne);
        return n != 0 ? n : a.prixParJour.compareTo(b.prixParJour);
      });
    return [
      for (final v in tries.take(3))
        (
          vehiculeId: v.id!,
          raison: '${v.type.libelle} ${v.carburant.libelle.toLowerCase()}, '
              '${v.places} places, ${v.prixParJour.toStringAsFixed(0)} DT/jour',
        ),
    ];
  }

  // ------------------------------------------------------------------
  // 3. Description attractive
  // ------------------------------------------------------------------

  /// Description de 2 à 3 phrases + hashtags, à partir de quelques mots du propriétaire.
  Future<String> genererDescription(Vehicule v, String motsCles) async {
    final json = await _gemini.genererJson(
      consigne: 'Tu rédiges des annonces de location de véhicules en Tunisie, en français, '
          'ton chaleureux et précis, sans exagération ni information inventée. '
          'Réponds UNIQUEMENT en JSON : {"description": "2 à 3 phrases", '
          '"hashtags": ["#mot", ...] (4 au maximum)}.',
      demande: 'Véhicule : ${jsonEncode(_resume([v]).first)}. Mots du propriétaire : $motsCles',
    );
    if (json is! Map || json['description'] is! String) {
      throw const IaException('Réponse de l\'IA incomplète. Réessayez.');
    }
    final tags = json['hashtags'] is List
        ? (json['hashtags'] as List).whereType<String>().take(4).join(' ')
        : '';
    return tags.isEmpty ? json['description'] as String : '${json['description']}\n$tags';
  }

  // ------------------------------------------------------------------
  // 4. Résumé des avis
  // ------------------------------------------------------------------

  Future<({String resume, List<String> positifs, List<String> negatifs})> resumerAvis(
      List<({int note, String? commentaire})> avis) async {
    if (avis.isEmpty) {
      return (resume: 'Aucun avis pour le moment.', positifs: <String>[], negatifs: <String>[]);
    }
    final textes = [
      for (final a in avis)
        '${a.note}/5${a.commentaire == null ? '' : ' : ${a.commentaire}'}',
    ];
    final json = await _gemini.genererJson(
      consigne: 'Résume des avis clients en français. Réponds UNIQUEMENT en JSON : '
          '{"resume": "une phrase", "positifs": ["…"], "negatifs": ["…"]} '
          '(3 points maximum par liste, listes vides si rien à dire).',
      demande: textes.join('\n'),
    );
    if (json is! Map) throw const IaException('Réponse de l\'IA illisible.');
    List<String> liste(Object? x) =>
        x is List ? x.whereType<String>().take(3).toList() : <String>[];
    return (
      resume: '${json['resume'] ?? ''}',
      positifs: liste(json['positifs']),
      negatifs: liste(json['negatifs']),
    );
  }

  // ------------------------------------------------------------------
  // 5. Estimation du prix juste
  // ------------------------------------------------------------------

  Future<({double min, double max, String justification, bool parIa})> estimerPrix(
      Vehicule v) async {
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu estimes le prix de location journalier en dinars tunisiens (DT) en '
              'Tunisie. Exemples : citadine essence 2018 -> 60-80 DT ; SUV diesel 2022 -> '
              '120-160 DT ; scooter 125 cm3 -> 35-50 DT ; vélo de ville -> 10-15 DT ; '
              'vélo électrique -> 20-30 DT. Réponds UNIQUEMENT en JSON : '
              '{"min": nombre, "max": nombre, "justification": "une phrase"}.',
          demande: jsonEncode(_resume([v]).first),
        );
        if (json is Map && json['min'] is num && json['max'] is num) {
          final min = (json['min'] as num).toDouble();
          final max = (json['max'] as num).toDouble();
          if (min > 0 && max >= min) {
            return (min: min, max: max, justification: '${json['justification'] ?? ''}', parIa: true);
          }
        }
      } on IaException {
        // Repli local.
      }
    }
    final e = estimationLocale(v);
    return (
      min: e.min,
      max: e.max,
      justification: 'Estimation locale : type, âge, motorisation et équipement.',
      parIa: false,
    );
  }

  /// Barème indicatif sans réseau.
  static ({double min, double max}) estimationLocale(Vehicule v) {
    var base = switch (v.type) {
      TypeVehicule.voiture => 75.0,
      TypeVehicule.moto => 42.0,
      TypeVehicule.bicyclette => 12.0,
    };
    if (v.annee != null) {
      final age = (DateTime.now().year - v.annee!).clamp(0, 15);
      base *= 1 - (age * 0.03).clamp(0.0, 0.4);
    }
    if (v.estElectrique) base *= v.type == TypeVehicule.bicyclette ? 1.8 : 1.1;
    if (v.boite == Boite.automatique) base *= 1.1;
    if (v.type == TypeVehicule.voiture && v.places > 5) base *= 1.15;
    double arrondi(double x) => (x * 2).round() / 2;
    return (min: arrondi(base * 0.85), max: arrondi(base * 1.15));
  }

  // ------------------------------------------------------------------
  // 6. Chatbot
  // ------------------------------------------------------------------

  /// Répond à une question en s'appuyant UNIQUEMENT sur la flotte fournie.
  Future<String> repondre(String question, List<Vehicule> flotte,
      {List<MessageAssistant> historique = const []}) async {
    final echanges = [
      for (final m in historique.take(10))
        '${m.deClient ? 'Client' : 'Assistant'} : ${m.texte}',
    ].join('\n');
    final json = await _gemini.genererJson(
      consigne: 'Tu es l\'assistant de location de véhicules de Travel Platform. Réponds en '
          'français, en 4 phrases maximum, UNIQUEMENT à partir des véhicules fournis '
          '(prix en DT par jour). Si l\'information manque, dis-le. '
          'Réponds en JSON : {"reponse": "texte"}.',
      demande: 'Véhicules : ${jsonEncode(_resume(flotte))}\n'
          '${echanges.isEmpty ? '' : 'Conversation :\n$echanges\n'}'
          'Question : $question',
    );
    if (json is Map && json['reponse'] is String) return json['reponse'] as String;
    throw const IaException('Réponse de l\'IA illisible.');
  }

  // ------------------------------------------------------------------
  // 7. Contrôle des photos (Hugging Face)
  // ------------------------------------------------------------------

  /// Modèle de vision utilisé : détection d'objets par défaut ; un modèle entraîné
  /// sur les dommages (rayures, bosses) peut être fourni par --dart-define=HF_MODELE_DOMMAGES.
  static const String modelePhotos =
      String.fromEnvironment('HF_MODELE_DOMMAGES', defaultValue: 'facebook/detr-resnet-50');

  /// Lecture des étiquettes du modèle : dommage signalé (score >= 0,5) et
  /// présence d'un véhicule du bon genre sur la photo.
  static ({bool dommage, bool vehiculeVisible}) interpreterEtiquettes(
      List<EtiquetteImage> etiquettes, TypeVehicule type) {
    const motsDommage = ['scratch', 'dent', 'damage', 'crack', 'broken', 'rayure', 'bosse'];
    final attendus = switch (type) {
      TypeVehicule.voiture => const ['car', 'truck', 'bus'],
      TypeVehicule.moto => const ['motorcycle', 'motorbike', 'scooter'],
      TypeVehicule.bicyclette => const ['bicycle', 'bike'],
    };
    bool contient(String label, List<String> mots) =>
        mots.any(label.toLowerCase().contains);
    return (
      dommage: etiquettes.any((e) => e.score >= 0.5 && contient(e.label, motsDommage)),
      vehiculeVisible: etiquettes.any((e) => e.score >= 0.5 && contient(e.label, attendus)),
    );
  }

  /// Données envoyées à l'IA : uniquement ce qui sert à répondre (pas de photos).
  static List<Map<String, Object?>> _resume(List<Vehicule> vehicules) => [
        for (final v in vehicules)
          {
            'id': v.id,
            'nom': v.nom,
            'type': v.type.valeur,
            'annee': v.annee,
            'carburant': v.carburant.valeur,
            'boite': v.boite?.valeur,
            'places': v.places,
            'prix_jour': v.prixParJour,
            'caution': v.caution,
            'note': v.nbAvis == 0 ? null : v.noteMoyenne,
            'disponible': v.disponible,
            'lieu': v.adresse,
          },
      ];
}
