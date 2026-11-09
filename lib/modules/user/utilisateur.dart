import 'role.dart';

class Utilisateur {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final Role role;
  final DateTime creeLe;

  const Utilisateur({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
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
        creeLe: DateTime.parse(m['cree_le'] as String),
      );

  Utilisateur copyWith({String? nom, String? prenom, String? telephone}) =>
      Utilisateur(
        id: id,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        email: email,
        telephone: telephone ?? this.telephone,
        role: role,
        creeLe: creeLe,
      );
}
