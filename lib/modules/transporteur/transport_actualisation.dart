import 'dart:async';

import 'package:flutter/widgets.dart';

/// Recharge en silence une liste du module transporteur : toutes les [intervalle],
/// et dès que l'application revient au premier plan. Les données restent affichées
/// pendant le rechargement (pas de spinner à chaque cycle).
class ActualisationAuto with WidgetsBindingObserver {
  ActualisationAuto({
    required this.rafraichir,
    this.intervalle = const Duration(seconds: 10),
  });

  /// Recharge la liste de l'écran.
  final VoidCallback rafraichir;
  final Duration intervalle;
  Timer? _minuterie;

  /// À appeler dans initState.
  void demarrer() {
    WidgetsBinding.instance.addObserver(this);
    _minuterie = Timer.periodic(intervalle, (_) => rafraichir());
  }

  /// À appeler dans dispose : aucun rechargement après la fermeture de l'écran.
  void arreter() {
    _minuterie?.cancel();
    _minuterie = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) rafraichir();
  }
}
