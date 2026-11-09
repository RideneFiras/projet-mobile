import 'role.dart';

class Utilisateur {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final Role role;
  /// Photo de profil encodée en base64 (null = initiales).
  final String? photo;
  final DateTime creeLe;

  const Utilisateur({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
    this.photo,
    required this.creeLe,
  });

  String get nomComplet => '$prenom $nom';

  String get initiales {
    final p = prenom.isNotEmpty ? prenom[0] : '';
    final n = nom.isNotEmpty ? nom[0] : '';
    return '$p$n'.toUpperCase();
  }

  factory Utilisateur.fromMap(Map<String, dynamic> m) => Utilisateur(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        prenom: m['prenom'] as String,
        email: m['email'] as String,
        telephone: m['telephone'] as String,
        role: Role.depuis(m['role'] as String),
        photo: m['photo'] as String?,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );

  Utilisateur copyWith({String? nom, String? prenom, String? telephone, String? photo, bool effacerPhoto = false}) =>
      Utilisateur(
        id: id,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        email: email,
        telephone: telephone ?? this.telephone,
        role: role,
        photo: effacerPhoto ? null : (photo ?? this.photo),
        creeLe: creeLe,
      );
}
