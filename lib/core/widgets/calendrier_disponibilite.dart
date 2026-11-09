import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/dates.dart';

/// Calendrier mensuel des disponibilités (sans package) : jours libres, pris ou bloqués,
/// sélection d'une période par deux appuis (début puis fin).
/// - [modeNuits] = false (location) : la période [début, fin] est entièrement louée.
/// - [modeNuits] = true (hébergement) : on dort du début à la veille de la fin ;
///   le jour du départ peut donc être un jour déjà pris.
/// [onPlage] null = calendrier en lecture seule.
class CalendrierDisponibilite extends StatefulWidget {
  final bool Function(DateTime jour) estIndisponible;
  final ValueChanged<DateTimeRange>? onPlage;
  final bool modeNuits;
  final DateTime? premierJour;

  const CalendrierDisponibilite({
    super.key,
    required this.estIndisponible,
    this.onPlage,
    this.modeNuits = false,
    this.premierJour,
  });

  @override
  State<CalendrierDisponibilite> createState() => _CalendrierDisponibiliteState();
}

class _CalendrierDisponibiliteState extends State<CalendrierDisponibilite> {
  static const _mois = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _joursSemaine = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late DateTime _moisAffiche;
  DateTime? _debut;
  DateTime? _fin;

  DateTime get _premier => dateJour(widget.premierJour ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _moisAffiche = DateTime(_premier.year, _premier.month);
  }

  bool _passe(DateTime j) => j.isBefore(_premier);

  /// Toutes les unités de la période sont libres.
  bool _plageLibre(DateTime debut, DateTime fin) {
    var j = debut;
    while (widget.modeNuits ? j.isBefore(fin) : !j.isAfter(fin)) {
      if (widget.estIndisponible(j)) return false;
      j = DateTime(j.year, j.month, j.day + 1);
    }
    return true;
  }

  void _toucher(DateTime j) {
    if (widget.onPlage == null || _passe(j)) return;
    final debut = _debut;
    final peutCommencer = !widget.estIndisponible(j);
    if (debut == null || _fin != null || !j.isAfter(debut)) {
      // Nouveau début (ou même jour en location : période d'un jour).
      if (debut != null && _fin == null && j == debut && !widget.modeNuits) {
        setState(() => _fin = j);
        widget.onPlage!(DateTimeRange(start: j, end: j));
        return;
      }
      if (!peutCommencer) {
        _signaler('Ce jour n\'est pas disponible');
        return;
      }
      setState(() {
        _debut = j;
        _fin = null;
      });
      return;
    }
    if (!_plageLibre(debut, j)) {
      _signaler('La période contient des jours indisponibles');
      return;
    }
    setState(() => _fin = j);
    widget.onPlage!(DateTimeRange(start: debut, end: j));
  }

  void _signaler(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    final premierDuMois = _moisAffiche;
    final decalage = premierDuMois.weekday - 1; // lundi = 0
    final joursDansMois = DateTime(premierDuMois.year, premierDuMois.month + 1, 0).day;
    final peutReculer = premierDuMois.isAfter(DateTime(_premier.year, _premier.month));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mois précédent',
                onPressed: peutReculer
                    ? () => setState(() => _moisAffiche =
                        DateTime(premierDuMois.year, premierDuMois.month - 1))
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('${_mois[premierDuMois.month - 1]} ${premierDuMois.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              IconButton(
                tooltip: 'Mois suivant',
                onPressed: () => setState(() =>
                    _moisAffiche = DateTime(premierDuMois.year, premierDuMois.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final j in _joursSemaine)
                Expanded(
                  child: Text(j,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              for (var i = 0; i < decalage; i++) const SizedBox.shrink(),
              for (var d = 1; d <= joursDansMois; d++)
                _case(DateTime(premierDuMois.year, premierDuMois.month, d)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legende(AppColors.white, 'Libre', bordure: true),
              _legende(const Color(0xFFFBE3E0), 'Indisponible'),
              if (widget.onPlage != null) _legende(AppColors.teal, 'Votre choix'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _case(DateTime j) {
    final passe = _passe(j);
    final pris = !passe && widget.estIndisponible(j);
    final estDebut = _debut == j;
    final estFin = _fin == j;
    final dedans = _debut != null &&
        _fin != null &&
        j.isAfter(_debut!) &&
        j.isBefore(_fin!);
    final selection = estDebut || estFin;

    Color fond = AppColors.white;
    Color texte = AppColors.navy;
    if (passe) {
      texte = AppColors.border;
    } else if (selection) {
      fond = AppColors.teal;
      texte = AppColors.white;
    } else if (dedans) {
      fond = AppColors.tealLight;
    } else if (pris) {
      fond = const Color(0xFFFBE3E0);
      texte = AppColors.danger;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fond,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: passe ? null : () => _toucher(j),
          child: Center(
            child: Text('${j.day}',
                style: TextStyle(
                  color: texte,
                  fontWeight: selection ? FontWeight.w800 : FontWeight.w600,
                  decoration: pris && !selection ? TextDecoration.lineThrough : null,
                )),
          ),
        ),
      ),
    );
  }

  Widget _legende(Color couleur, String libelle, {bool bordure = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: BorderRadius.circular(4),
              border: bordure ? Border.all(color: AppColors.border) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(libelle, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      );
}
