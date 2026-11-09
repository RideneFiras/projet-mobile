/// Fiche d'un transporteur (table "transporteur").
class Transporteur {
  static const List<String> types = ['Bus', 'Train', 'Avion', 'Bateau', 'Covoiturage'];

  final int? id;
  final String nom;
  final String type;
  final String contact;

  const Transporteur({
    this.id,
    required this.nom,
    required this.type,
    required this.contact,
  });

  factory Transporteur.fromMap(Map<String, dynamic> m) => Transporteur(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        type: m['type'] as String,
        contact: m['contact'] as String,
      );

  Map<String, dynamic> toMap() => {
        'nom': nom.trim(),
        'type': type,
        'contact': contact.trim(),
      };

  Transporteur copyWith({String? nom, String? type, String? contact}) =>
      Transporteur(
        id: id,
        nom: nom ?? this.nom,
        type: type ?? this.type,
        contact: contact ?? this.contact,
      );
}
