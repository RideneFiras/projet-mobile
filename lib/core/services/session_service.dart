import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise SEULEMENT l'identifiant de l'utilisateur connecté.
/// Le rôle est relu dans la base à chaque fois (on ne peut pas devenir
/// admin en modifiant les préférences).
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const String _cle = 'utilisateur_id';

  Future<void> ouvrir(int id) async =>
      (await SharedPreferences.getInstance()).setInt(_cle, id);

  Future<int?> utilisateurId() async =>
      (await SharedPreferences.getInstance()).getInt(_cle);

  Future<void> fermer() async =>
      (await SharedPreferences.getInstance()).remove(_cle);
}
