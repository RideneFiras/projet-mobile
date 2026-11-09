import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/choisir_position_screen.dart';
import '../models/filtres_hebergement.dart';

/// Panneau des filtres avancés des établissements ; renvoie les nouveaux filtres.
Future<FiltresHebergement?> ouvrirFiltresHebergement(
    BuildContext context, FiltresHebergement actuels,
    {double prixPlafond = 600}) {
  return showModalBottomSheet<FiltresHebergement>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _Panneau(actuels: actuels, prixPlafond: prixPlafond),
  );
}

class _Panneau extends StatefulWidget {
  final FiltresHebergement actuels;
  final double prixPlafond;

  const _Panneau({required this.actuels, required this.prixPlafond});

  @override
  State<_Panneau> createState() => _PanneauState();
}

class _PanneauState extends State<_Panneau> {
  late FiltresHebergement _f;
  late RangeValues _prix;

  @override
  void initState() {
    super.initState();
    _f = widget.actuels;
    _prix = RangeValues(
      (_f.prixMin ?? 0).clamp(0, widget.prixPlafond).toDouble(),
      (_f.prixMax ?? widget.prixPlafond).clamp(0, widget.prixPlafond).toDouble(),
    );
  }

  Future<void> _choisirDates() async {
    final auj = dateJour(DateTime.now());
    final plage = await showDateRangePicker(
      context: context,
      firstDate: auj,
      lastDate: DateTime(auj.year + 2, 12, 31),
      helpText: 'Arrivée → départ',
    );
    if (plage != null && mounted && plage.end.isAfter(plage.start)) {
      setState(() => _f = _f.copyWith(arrivee: plage.start, depart: plage.end));
    }
  }

  Future<void> _choisirPosition() async {
    final r = await Navigator.push<PositionChoisie>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChoisirPositionScreen(latitude: _f.latitudeRef, longitude: _f.longitudeRef),
      ),
    );
    if (r != null && mounted) {
      setState(() => _f = _f.copyWith(latitudeRef: r.latitude, longitudeRef: r.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plafond = widget.prixPlafond;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Filtres',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _f = _f.reinitialises();
                    _prix = RangeValues(0, plafond);
                  }),
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
            _titre('Prix par nuit : ${_prix.start.round()} – ${_prix.end.round()} DT'
                '${_prix.end >= plafond ? '+' : ''}'),
            RangeSlider(
              values: _prix,
              min: 0,
              max: plafond,
              divisions: (plafond / 10).round(),
              activeColor: AppColors.teal,
              labels: RangeLabels('${_prix.start.round()}', '${_prix.end.round()}'),
              onChanged: (v) => setState(() => _prix = v),
            ),
            _titre('Étoiles minimum'),
            Wrap(
              spacing: 8,
              children: [
                for (final e in [null, 2, 3, 4, 5])
                  _puce(e == null ? 'Toutes' : '$e ★+', _f.etoilesMin == e,
                      () => setState(() => _f = e == null
                          ? _f.copyWith(effacerEtoiles: true)
                          : _f.copyWith(etoilesMin: e))),
              ],
            ),
            _titre('Note des voyageurs'),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [null, 3.0, 4.0, 4.5])
                  _puce(n == null ? 'Toutes' : '${n.toStringAsFixed(n == 4.5 ? 1 : 0)}+ / 5',
                      _f.noteMin == n,
                      () => setState(() => _f = n == null
                          ? _f.copyWith(effacerNote: true)
                          : _f.copyWith(noteMin: n))),
              ],
            ),
            _titre('Voyageurs'),
            Wrap(
              spacing: 8,
              children: [
                for (final p in [null, 1, 2, 4, 6, 10])
                  _puce(p == null ? 'Peu importe' : '$p+', _f.personnes == p,
                      () => setState(() => _f = p == null
                          ? _f.copyWith(effacerPersonnes: true)
                          : _f.copyWith(personnes: p))),
              ],
            ),
            _titre('Disponibilité'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choisirDates,
                    icon: const Icon(Icons.date_range),
                    label: Text(_f.aDates
                        ? periode(_f.arrivee!, _f.depart!)
                        : 'Libre entre deux dates'),
                  ),
                ),
                if (_f.aDates)
                  IconButton(
                    tooltip: 'Retirer les dates',
                    onPressed: () => setState(() => _f = _f.copyWith(effacerDates: true)),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _choisirPosition,
              icon: const Icon(Icons.my_location),
              label: Text(_f.aPositionRef
                  ? 'Ma position : ${_f.latitudeRef!.toStringAsFixed(3)}, '
                      '${_f.longitudeRef!.toStringAsFixed(3)} (modifier)'
                  : 'Indiquer ma position (« proche de moi »)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _f.copyWith(effacerPrix: true).copyWith(
                        prixMin: _prix.start > 0 ? _prix.start : null,
                        prixMax: _prix.end < plafond ? _prix.end : null,
                      ),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Appliquer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(texte,
            style: const TextStyle(
                color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _puce(String libelle, bool actif, VoidCallback onTap) => ChoiceChip(
        label: Text(libelle),
        selected: actif,
        showCheckmark: false,
        selectedColor: AppColors.teal,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.border),
        labelStyle: TextStyle(
            fontWeight: FontWeight.w600, color: actif ? AppColors.white : AppColors.navy),
        onSelected: (_) => onTap(),
      );
}
