import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../models/filtres_vehicule.dart';
import '../models/vehicule.dart';
import '../../../core/widgets/choisir_position_screen.dart';

/// Ouvre le panneau des filtres avancés ; renvoie les nouveaux filtres (null si fermé).
Future<FiltresVehicule?> ouvrirFiltresVehicule(BuildContext context, FiltresVehicule actuels,
    {double prixPlafond = 300}) {
  return showModalBottomSheet<FiltresVehicule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PanneauFiltres(actuels: actuels, prixPlafond: prixPlafond),
  );
}

class _PanneauFiltres extends StatefulWidget {
  final FiltresVehicule actuels;
  final double prixPlafond;

  const _PanneauFiltres({required this.actuels, required this.prixPlafond});

  @override
  State<_PanneauFiltres> createState() => _PanneauFiltresState();
}

class _PanneauFiltresState extends State<_PanneauFiltres> {
  late FiltresVehicule _f;
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
      helpText: 'Disponible du … au …',
    );
    if (plage != null && mounted) {
      setState(() => _f = _f.copyWith(disponibleDu: plage.start, disponibleAu: plage.end));
    }
  }

  Future<void> _choisirPosition() async {
    final r = await Navigator.push<PositionChoisie>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoisirPositionScreen(
            latitude: _f.latitudeRef, longitude: _f.longitudeRef),
      ),
    );
    if (r != null && mounted) {
      setState(() => _f = _f.copyWith(
          latitudeRef: r.latitude, longitudeRef: r.longitude, tri: TriVehicule.distance));
    }
  }

  void _appliquer() {
    final plafond = widget.prixPlafond;
    Navigator.pop(
      context,
      _f.copyWith(
        effacerPrix: true,
      ).copyWith(
        prixMin: _prix.start > 0 ? _prix.start : null,
        prixMax: _prix.end < plafond ? _prix.end : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anneeActuelle = DateTime.now().year;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      _prix = RangeValues(0, widget.prixPlafond);
                    }),
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
              _titre('Prix par jour : ${_prix.start.round()} – ${_prix.end.round()} DT'
                  '${_prix.end >= widget.prixPlafond ? '+' : ''}'),
              RangeSlider(
                values: _prix,
                min: 0,
                max: widget.prixPlafond,
                divisions: (widget.prixPlafond / 5).round(),
                activeColor: AppColors.teal,
                labels: RangeLabels('${_prix.start.round()}', '${_prix.end.round()}'),
                onChanged: (v) => setState(() => _prix = v),
              ),
              _titre('Année minimale'),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in [null, anneeActuelle - 10, anneeActuelle - 5, anneeActuelle - 2])
                    _puce(a == null ? 'Toutes' : 'Depuis $a', _f.anneeMin == a,
                        () => setState(() => _f = a == null
                            ? _f.copyWith(effacerAnnee: true)
                            : _f.copyWith(anneeMin: a))),
                ],
              ),
              _titre('Motorisation'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _puce('Toutes', _f.carburant == null,
                      () => setState(() => _f = _f.copyWith(effacerCarburant: true))),
                  for (final c in Carburant.values)
                    _puce(c.libelle, _f.carburant == c,
                        () => setState(() => _f = _f.copyWith(carburant: c))),
                ],
              ),
              _titre('Boîte de vitesses'),
              Wrap(
                spacing: 8,
                children: [
                  _puce('Toutes', _f.boite == null,
                      () => setState(() => _f = _f.copyWith(effacerBoite: true))),
                  for (final b in Boite.values)
                    _puce(b.libelle, _f.boite == b,
                        () => setState(() => _f = _f.copyWith(boite: b))),
                ],
              ),
              _titre('Places minimum'),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in [null, 2, 4, 5, 7])
                    _puce(p == null ? 'Peu importe' : '$p+', _f.placesMin == p,
                        () => setState(() => _f = p == null
                            ? _f.copyWith(effacerPlaces: true)
                            : _f.copyWith(placesMin: p))),
                ],
              ),
              _titre('Disponibilité'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _choisirDates,
                      icon: const Icon(Icons.date_range),
                      label: Text(_f.disponibleDu == null || _f.disponibleAu == null
                          ? 'Disponible entre deux dates'
                          : periode(_f.disponibleDu!, _f.disponibleAu!)),
                    ),
                  ),
                  if (_f.disponibleDu != null)
                    IconButton(
                      tooltip: 'Retirer les dates',
                      onPressed: () => setState(() => _f = _f.copyWith(effacerDates: true)),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              _titre('Trier par'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TriVehicule.values)
                    _puce(t.libelle, _f.tri == t, () {
                      if (t == TriVehicule.distance && !_f.aPositionRef) {
                        _choisirPosition();
                      } else {
                        setState(() => _f = _f.copyWith(tri: t));
                      }
                    }),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _choisirPosition,
                icon: const Icon(Icons.my_location),
                label: Text(_f.aPositionRef
                    ? 'Ma position : ${_f.latitudeRef!.toStringAsFixed(3)}, '
                        '${_f.longitudeRef!.toStringAsFixed(3)} (modifier)'
                    : 'Indiquer ma position (tri par distance)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _appliquer,
                  icon: const Icon(Icons.check),
                  label: const Text('Appliquer'),
                ),
              ),
            ],
          ),
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
