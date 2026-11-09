import 'dart:convert';

import '../../core/services/gemini_service.dart';
import '../../core/services/hugging_face_service.dart';
import 'models/filtres_hebergement.dart';
import 'models/hebergement.dart';

/// Profil de voyageur pour la recommandation.
enum ProfilVoyageur {
  famille('famille', 'Famille'),
  couple('couple', 'Couple'),
  affaires('affaires', 'Affaires'),
  solo('solo', 'Solo'),
  amis('amis', 'Entre amis');

  const ProfilVoyageur(this.valeur, this.libelle);

  final String valeur;
  final String libelle;
}

/// Message d'une conversation avec le concierge.
typedef MessageConcierge = ({bool deClient, String texte});

/// Jour d'un itinéraire proposé par l'IA.
typedef JourItineraire = ({String titre, String programme});

/// Fonctions d'IA du module hébergement (Google Gemini, Hugging Face) :
/// recherche en langage naturel, recommandation selon le profil, description SEO,
/// résumé des avis, prix conseillé, concierge, itinéraire + hébergement,
/// détection de photos générées par IA. Repli local quand c'est possible.
class HebergementIaService {
  final GeminiService _gemini;

  HebergementIaService({GeminiService? gemini}) : _gemini = gemini ?? GeminiService();

  bool get configure => _gemini.configure;

  // ------------------------------------------------------------------
  // Recherche en langage naturel
  // ------------------------------------------------------------------

  Future<({FiltresHebergement filtres, bool parIa})> analyserDemande(String texte) async {
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu transformes une recherche d\'hébergement en filtres. Réponds UNIQUEMENT '
              'en JSON : {"type": "hotel"|"auberge"|"appartement"|"maison_hotes"|"villa"|'
              '"riad"|"camping"|null, "prix_max": nombre|null (DT par nuit), '
              '"etoiles_min": 1-5|null, "personnes": entier|null, "ville": texte|null, '
              '"equipements": liste parmi ["wifi","parking","piscine","climatisation",'
              '"petit_dejeuner","restaurant","spa","salle_sport","plage","cuisine","navette",'
              '"animaux"]}.',
          demande: texte,
        );
        if (json is Map) return (filtres: filtresDepuisJson(json), parIa: true);
      } on IaException {
        // Repli local.
      }
    }
    return (filtres: analyseLocale(texte), parIa: false);
  }

  static FiltresHebergement filtresDepuisJson(Map json) {
    TypeHebergement? type;
    for (final t in TypeHebergement.values) {
      if (t.valeur == json['type']) type = t;
    }
    final prix = json['prix_max'];
    final etoiles = json['etoiles_min'];
    final personnes = json['personnes'];
    final ville = json['ville'];
    return FiltresHebergement(
      type: type,
      prixMax: prix is num && prix > 0 ? prix.toDouble() : null,
      etoilesMin: etoiles is num && etoiles >= 1 && etoiles <= 5 ? etoiles.toInt() : null,
      personnes: personnes is num && personnes > 0 ? personnes.toInt() : null,
      recherche: ville is String && ville.trim().isNotEmpty ? ville.trim() : null,
      equipements: {
        if (json['equipements'] is List)
          for (final e in json['equipements'] as List)
            if (e is String)
              if (Equipement.depuis(e) case final eq?) eq,
      },
    );
  }

  /// Analyse par mots-clés, sans réseau.
  static FiltresHebergement analyseLocale(String texte) {
    final t = texte.toLowerCase();
    bool contient(List<String> mots) => mots.any(t.contains);
    TypeHebergement? type;
    for (final (mots, valeur) in [
      (['riad'], TypeHebergement.riad),
      (['villa'], TypeHebergement.villa),
      (['appartement', 'studio'], TypeHebergement.appartement),
      (['maison d\'hôtes', 'maison d\'hotes', 'dar '], TypeHebergement.maisonHotes),
      (['auberge', 'hostel'], TypeHebergement.auberge),
      (['camping', 'tente', 'glamping'], TypeHebergement.camping),
      (['hôtel', 'hotel'], TypeHebergement.hotel),
    ]) {
      if (contient(mots)) {
        type = valeur;
        break;
      }
    }
    final equipements = <Equipement>{
      if (contient(['piscine'])) Equipement.piscine,
      if (contient(['wifi', 'wi-fi', 'internet'])) Equipement.wifi,
      if (contient(['parking', 'garer'])) Equipement.parking,
      if (contient(['clim'])) Equipement.climatisation,
      if (contient(['petit-déjeuner', 'petit déjeuner', 'petit-dej'])) Equipement.petitDejeuner,
      if (contient(['plage', 'mer', 'bord de l\'eau'])) Equipement.plage,
      if (contient(['spa', 'hammam'])) Equipement.spa,
      if (contient(['animaux', 'chien', 'chat'])) Equipement.animaux,
      if (contient(['cuisine'])) Equipement.cuisine,
    };
    final budget = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:dt|tnd|dinars?)').firstMatch(t);
    final personnes = RegExp(r'(\d+)\s*(?:personnes?|pers\b|adultes?|voyageurs?)').firstMatch(t);
    final etoiles = RegExp(r'([1-5])\s*(?:étoiles?|etoiles?|\*)').firstMatch(t);
    int? nb = personnes == null ? null : int.tryParse(personnes.group(1)!);
    if (nb == null && contient(['famille', 'enfants'])) nb = 4;
    if (nb == null && contient(['couple', 'romantique', 'lune de miel'])) nb = 2;
    return FiltresHebergement(
      type: type,
      equipements: equipements,
      prixMax: budget == null ? null : double.tryParse(budget.group(1)!.replaceAll(',', '.')),
      personnes: nb,
      etoilesMin: etoiles == null ? null : int.parse(etoiles.group(1)!),
    );
  }

  // ------------------------------------------------------------------
  // Recommandation selon le profil
  // ------------------------------------------------------------------

  Future<List<({int hebergementId, String raison})>> recommander(
      String demande, ProfilVoyageur? profil, List<Hebergement> candidats) async {
    if (candidats.isEmpty) return const [];
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu es conseiller voyage en Tunisie. Choisis au plus 3 établissements de la '
              'liste adaptés au profil et à la demande. Réponds UNIQUEMENT en JSON : '
              '[{"id": entier, "raison": "phrase courte"}]. Utilise seulement les id fournis.',
          demande: 'Profil : ${profil?.libelle ?? 'non précisé'}. Demande : $demande\n'
              'Établissements : ${jsonEncode(_resume(candidats))}',
        );
        final ids = {for (final h in candidats) h.id};
        if (json is List) {
          final choix = [
            for (final e in json)
              if (e is Map && e['id'] is num && ids.contains((e['id'] as num).toInt()))
                (hebergementId: (e['id'] as num).toInt(), raison: '${e['raison'] ?? ''}'),
          ];
          if (choix.isNotEmpty) return choix.take(3).toList();
        }
      } on IaException {
        // Repli local.
      }
    }
    return recommandationLocale(profil, candidats);
  }

  /// Score par profil : équipements utiles, capacité, note, prix.
  static List<({int hebergementId, String raison})> recommandationLocale(
      ProfilVoyageur? profil, List<Hebergement> candidats) {
    final utiles = switch (profil) {
      ProfilVoyageur.famille => [Equipement.piscine, Equipement.parking, Equipement.cuisine],
      ProfilVoyageur.couple => [Equipement.spa, Equipement.plage, Equipement.restaurant],
      ProfilVoyageur.affaires => [Equipement.wifi, Equipement.navette, Equipement.salleSport],
      ProfilVoyageur.solo => [Equipement.wifi, Equipement.petitDejeuner],
      ProfilVoyageur.amis => [Equipement.piscine, Equipement.cuisine, Equipement.wifi],
      null => <Equipement>[],
    };
    double score(Hebergement h) {
      var s = h.noteMoyenne + utiles.where(h.possede).length * 1.5;
      if (profil == ProfilVoyageur.famille && h.capaciteTotale >= 4) s += 2;
      if (profil == ProfilVoyageur.affaires && h.type == TypeHebergement.hotel) s += 1;
      return s - h.prixParNuit / 200;
    }

    final tries = [...candidats.where((h) => h.ouvert)]
      ..sort((a, b) => score(b).compareTo(score(a)));
    return [
      for (final h in tries.take(3))
        (
          hebergementId: h.id!,
          raison: [
            h.type.libelle,
            if (h.nbAvis > 0) '${h.noteMoyenne.toStringAsFixed(1)}/5',
            ...utiles.where(h.possede).map((e) => e.libelle.toLowerCase()),
            '${h.prixParNuit.toStringAsFixed(0)} DT/nuit',
          ].join(' · '),
        ),
    ];
  }

  // ------------------------------------------------------------------
  // Description SEO, résumé d'avis, prix conseillé
  // ------------------------------------------------------------------

  /// Description vendeuse et précise + points forts, à partir de quelques mots.
  Future<String> genererDescription(Hebergement h, String motsCles) async {
    final json = await _gemini.genererJson(
      consigne: 'Tu rédiges des annonces d\'hébergement en Tunisie, en français, optimisées '
          'pour la recherche (mots-clés naturels : ville, type, atouts), sans rien inventer. '
          'Réponds UNIQUEMENT en JSON : {"description": "3 phrases", '
          '"points_forts": ["…", "…", "…"]}.',
      demande: 'Établissement : ${jsonEncode(_resume([h]).first)}. Mots du propriétaire : $motsCles',
    );
    if (json is! Map || json['description'] is! String) {
      throw const IaException('Réponse de l\'IA incomplète. Réessayez.');
    }
    final points = json['points_forts'] is List
        ? (json['points_forts'] as List).whereType<String>().take(4).map((p) => '• $p').join('\n')
        : '';
    return points.isEmpty ? json['description'] as String : '${json['description']}\n\n$points';
  }

  Future<({String resume, List<String> positifs, List<String> negatifs})> resumerAvis(
      List<({int note, String? commentaire})> avis) async {
    if (avis.isEmpty) {
      return (resume: 'Aucun avis pour le moment.', positifs: <String>[], negatifs: <String>[]);
    }
    final json = await _gemini.genererJson(
      consigne: 'Analyse le sentiment de ces avis d\'hôtel et résume-les en français. '
          'Réponds UNIQUEMENT en JSON : {"resume": "une phrase", "positifs": ["…"], '
          '"negatifs": ["…"]} (3 points maximum par liste).',
      demande: [
        for (final a in avis) '${a.note}/5${a.commentaire == null ? '' : ' : ${a.commentaire}'}',
      ].join('\n'),
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

  Future<({double min, double max, String justification, bool parIa})> estimerPrixNuit(
      Hebergement h) async {
    if (configure) {
      try {
        final json = await _gemini.genererJson(
          consigne: 'Tu estimes un prix par nuit concurrentiel en dinars tunisiens (DT), en '
              'Tunisie, selon le type, la ville, les étoiles et les équipements. Exemples : '
              'auberge -> 40-70 DT ; hôtel 3* Hammamet -> 120-180 DT ; hôtel 5* Djerba -> '
              '300-450 DT ; riad médina -> 180-280 DT. Réponds UNIQUEMENT en JSON : '
              '{"min": nombre, "max": nombre, "justification": "une phrase"}.',
          demande: jsonEncode(_resume([h]).first),
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
    final e = estimationLocale(h);
    return (
      min: e.min,
      max: e.max,
      justification: 'Barème local : type, étoiles, équipements et capacité.',
      parIa: false,
    );
  }

  static ({double min, double max}) estimationLocale(Hebergement h) {
    var base = switch (h.type) {
      TypeHebergement.hotel => 90.0 + 45 * ((h.etoiles ?? 3) - 1),
      TypeHebergement.auberge => 50.0,
      TypeHebergement.appartement => 110.0,
      TypeHebergement.maisonHotes => 140.0,
      TypeHebergement.villa => 320.0,
      TypeHebergement.riad => 220.0,
      TypeHebergement.camping => 35.0,
    };
    base *= 1 + 0.05 * h.equipements.length.clamp(0, 8);
    if (h.capacite > 2) base *= 1 + 0.1 * (h.capacite - 2).clamp(0, 6);
    double arrondi(double x) => (x / 5).round() * 5.0;
    return (min: arrondi(base * 0.85), max: arrondi(base * 1.15));
  }

  // ------------------------------------------------------------------
  // Concierge et itinéraire
  // ------------------------------------------------------------------

  /// Répond à une question sur UN établissement, uniquement à partir de sa fiche.
  Future<String> concierge(String question, Hebergement h,
      {List<MessageConcierge> historique = const []}) async {
    final echanges = [
      for (final m in historique.take(10)) '${m.deClient ? 'Client' : 'Concierge'} : ${m.texte}',
    ].join('\n');
    final json = await _gemini.genererJson(
      consigne: 'Tu es le concierge de l\'établissement décrit. Réponds en français, poliment, '
          'en 3 phrases maximum, UNIQUEMENT avec les informations de la fiche. Si la fiche ne '
          'contient pas la réponse (ex. piscine chauffée), dis-le et propose de contacter '
          'l\'établissement. Réponds en JSON : {"reponse": "texte"}.',
      demande: 'Fiche : ${jsonEncode(_resume([h], complet: true).first)}\n'
          '${echanges.isEmpty ? '' : 'Conversation :\n$echanges\n'}Question : $question',
    );
    if (json is Map && json['reponse'] is String) return json['reponse'] as String;
    throw const IaException('Réponse de l\'IA illisible.');
  }

  /// « 5 jours à Hammamet, 400 DT » : programme jour par jour + hébergements de la base.
  Future<({List<JourItineraire> jours, List<({int hebergementId, String raison})> hebergements, String conseil})>
      itineraire({
    required String destination,
    required int jours,
    required double budget,
    required List<Hebergement> candidats,
  }) async {
    final json = await _gemini.genererJson(
      consigne: 'Tu es un agent de voyage tunisien. Propose un programme jour par jour et '
          'choisis au plus 2 hébergements de la liste compatibles avec le budget total '
          '(hébergement compris). Réponds UNIQUEMENT en JSON : {"jours": [{"titre": "…", '
          '"programme": "2 phrases"}], "hebergements": [{"id": entier, "raison": "…"}], '
          '"conseil": "une phrase"}. Utilise seulement les id fournis.',
      demande: 'Destination : $destination. Durée : $jours jours. Budget total : '
          '${budget.toStringAsFixed(0)} DT.\nHébergements : ${jsonEncode(_resume(candidats))}',
    );
    if (json is! Map || json['jours'] is! List) {
      throw const IaException('Réponse de l\'IA incomplète. Réessayez.');
    }
    final ids = {for (final h in candidats) h.id};
    return (
      jours: [
        for (final j in json['jours'] as List)
          if (j is Map) (titre: '${j['titre'] ?? ''}', programme: '${j['programme'] ?? ''}'),
      ],
      hebergements: [
        if (json['hebergements'] is List)
          for (final e in json['hebergements'] as List)
            if (e is Map && e['id'] is num && ids.contains((e['id'] as num).toInt()))
              (hebergementId: (e['id'] as num).toInt(), raison: '${e['raison'] ?? ''}'),
      ],
      conseil: '${json['conseil'] ?? ''}',
    );
  }

  // ------------------------------------------------------------------
  // Photos générées par IA (Hugging Face)
  // ------------------------------------------------------------------

  static const String modeleFaussesPhotos = String.fromEnvironment('HF_MODELE_FAUSSES_PHOTOS',
      defaultValue: 'umm-maybe/AI-image-detector');

  /// Probabilité (0 à 1) que la photo soit générée par IA, d'après les étiquettes du modèle.
  static double probabiliteArtificielle(List<EtiquetteImage> etiquettes) {
    for (final e in etiquettes) {
      final l = e.label.toLowerCase();
      if (l.contains('artificial') || l.contains('fake') || l == 'ai' || l.contains('generated')) {
        return e.score;
      }
    }
    for (final e in etiquettes) {
      final l = e.label.toLowerCase();
      if (l.contains('human') || l.contains('real')) return 1 - e.score;
    }
    return 0;
  }

  /// Données envoyées à l'IA (pas de photos ; fiche complète pour le concierge).
  static List<Map<String, Object?>> _resume(List<Hebergement> liste, {bool complet = false}) => [
        for (final h in liste)
          {
            'id': h.id,
            'nom': h.nom,
            'type': h.type.libelle,
            'ville': h.ville,
            'etoiles': h.etoiles,
            'prix_nuit': h.prixParNuit,
            'capacite_par_chambre': h.capacite,
            'chambres': h.nbChambres,
            'equipements': h.equipements.map((e) => e.libelle).toList(),
            'note': h.nbAvis == 0 ? null : h.noteMoyenne,
            if (complet) ...{
              'adresse': h.adresseComplete,
              'description': h.description,
              'regles': h.regles,
              'arrivee': 'dès ${h.heureArrivee}',
              'depart': 'avant ${h.heureDepart}',
              'telephone': h.telephone,
              'superficie_m2': h.superficie,
              'statut': h.statut.libelle,
            },
          },
      ];
}
