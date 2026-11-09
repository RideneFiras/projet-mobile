import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import 'models/trajet_transport.dart';
import 'transport_carte_trajet.dart';
import 'transport_trajet_api.dart';
import 'transport_widgets.dart';

/// Feuille du bas : itinéraire routier (distance et durée) d'un trajet.
Future<void> afficherItineraire(BuildContext context, TrajetTransport trajet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FeuilleItineraire(trajet: trajet),
  );
}

class FeuilleItineraire extends StatefulWidget {
  final TrajetTransport trajet;

  const FeuilleItineraire({super.key, required this.trajet});

  @override
  State<FeuilleItineraire> createState() => _FeuilleItineraireState();
}

class _FeuilleItineraireState extends State<FeuilleItineraire> {
  late final Future<ItineraireTrajet> _itineraire;

  @override
  void initState() {
    super.initState();
    final t = widget.trajet;
    _itineraire = TrajetApiService.itineraire(t.villeDepart, t.destination);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trajet;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Itinéraire',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LigneTrajet(depart: t.villeDepart, arrivee: t.destination),
            const SizedBox(height: 4),
            LigneInfo(icone: Icons.event_outlined, texte: dateCourte(t.dateDepart)),
            const SizedBox(height: 18),
            const _Titre('Itinéraire routier'),
            FutureBuilder<ItineraireTrajet>(
              future: _itineraire,
              builder: (context, snap) => _contenuItineraire(snap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenuItineraire(AsyncSnapshot<ItineraireTrajet> snap) {
    if (snap.connectionState != ConnectionState.done) return _chargement();
    if (snap.hasError) return _erreur(snap.error);
    final it = snap.data!;
    final r = it.recommande;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LigneInfo(
          icone: Icons.route,
          texte: '${_km(r.distanceKm)} · ${_duree(r.dureeMin)}',
        ),
        const SizedBox(height: 4),
        LigneInfo(
          icone: it.estime ? Icons.calculate_outlined : Icons.alt_route,
          texte: it.estime
              ? 'Estimation à partir des coordonnées, sans tracé routier'
              : 'Calcul routier · OpenRouteService',
        ),
        if (it.avertissement != null) ...[
          const SizedBox(height: 6),
          Text(it.avertissement!,
              style: const TextStyle(color: AppColors.orangeText, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        CarteTrajet(
          trace: r.trace,
          depart: it.pointDepart,
          arrivee: it.pointArrivee,
          estime: it.estime,
        ),
        for (final alt in it.alternatives) ...[
          const SizedBox(height: 4),
          LigneInfo(
            icone: Icons.more_horiz,
            texte: 'Autre route : ${_km(alt.distanceKm)} · ${_duree(alt.dureeMin)}',
          ),
        ],
      ],
    );
  }

  Widget _chargement() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _erreur(Object? erreur) => Text(
        erreur is ErreurTrajetApi ? erreur.message : 'Information indisponible pour le moment.',
        style: const TextStyle(color: AppColors.danger, fontSize: 14),
      );

  static String _km(double km) =>
      km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';

  static String _duree(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '$h h ${m.toString().padLeft(2, '0')} min' : '$m min';
  }
}

class _Titre extends StatelessWidget {
  final String texte;

  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texte,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy)),
      );
}
