import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/geocodage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/choisir_position_screen.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_ia_service.dart';
import '../location_repository.dart';
import '../models/vehicule.dart';

/// Ajout ou modification d'un véhicule (voiture, moto, bicyclette).
/// Les champs s'adaptent au type. La position se renseigne à la main, par géocodage
/// de l'adresse (Nominatim) ou en touchant une carte. Renvoie true si enregistré.
class VehiculeFormScreen extends StatefulWidget {
  final Vehicule? vehicule;

  const VehiculeFormScreen({super.key, this.vehicule});

  @override
  State<VehiculeFormScreen> createState() => _VehiculeFormScreenState();
}

class _VehiculeFormScreenState extends State<VehiculeFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = LocationRepository();
  final _geocodage = GeocodageService();
  late final TextEditingController _marque;
  late final TextEditingController _modele;
  late final TextEditingController _annee;
  late final TextEditingController _couleur;
  late final TextEditingController _immat;
  late final TextEditingController _places;
  late final TextEditingController _kilometrage;
  late final TextEditingController _prix;
  late final TextEditingController _caution;
  late final TextEditingController _intervalle;
  late final TextEditingController _weekend;
  late final TextEditingController _saison;
  late final TextEditingController _remise;
  final _ia = LocationIaService();
  bool _iaEnCours = false;
  late final TextEditingController _adresse;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _photos;
  late final TextEditingController _description;
  late TypeVehicule _type;
  late Carburant _carburant;
  Boite? _boite;
  late StatutVehicule _statut;
  String? _erreur;
  bool _enregistrement = false;

  /// Action de géocodage en cours (affiche un indicateur sur son bouton).
  _Geo? _geoEnCours;

  bool get _modeEdition => widget.vehicule != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicule;
    String nombre(double? d) => d == null ? '' : '$d';
    _type = v?.type ?? TypeVehicule.voiture;
    _carburant = v?.carburant ?? Carburant.essence;
    _boite = v?.boite ?? Boite.manuelle;
    _statut = v?.statut ?? StatutVehicule.disponible;
    _marque = TextEditingController(text: v?.marque ?? '');
    _modele = TextEditingController(text: v?.modele ?? '');
    _annee = TextEditingController(text: v?.annee?.toString() ?? '');
    _couleur = TextEditingController(text: v?.couleur ?? '');
    _immat = TextEditingController(text: v?.immatriculation ?? '');
    _places = TextEditingController(text: '${v?.places ?? _type.placesParDefaut}');
    _kilometrage = TextEditingController(text: v?.kilometrage?.toString() ?? '');
    _prix = TextEditingController(text: v == null ? '' : v.prixParJour.toStringAsFixed(2));
    _caution = TextEditingController(text: v == null ? '0' : v.caution.toStringAsFixed(2));
    String pourcent(double? x) => (x ?? 0).toStringAsFixed(0);
    _intervalle = TextEditingController(text: '${v?.intervalleRevision ?? 10000}');
    _weekend = TextEditingController(text: pourcent(v?.majorationWeekend));
    _saison = TextEditingController(text: pourcent(v?.majorationSaison));
    _remise = TextEditingController(text: pourcent(v?.remiseLongueDuree));
    _adresse = TextEditingController(text: v?.adresse ?? '');
    _latitude = TextEditingController(text: nombre(v?.latitude));
    _longitude = TextEditingController(text: nombre(v?.longitude));
    _photos = TextEditingController(text: (v?.photos ?? const []).join('\n'));
    _description = TextEditingController(text: v?.description ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _marque, _modele, _annee, _couleur, _immat, _places, _kilometrage, _prix, _caution,
      _intervalle, _weekend, _saison, _remise,
      _adresse, _latitude, _longitude, _photos, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Changer de type remet les champs dépendants dans un état valide.
  void _choisirType(TypeVehicule t) => setState(() {
        _type = t;
        if (!t.carburants.contains(_carburant)) _carburant = t.carburants.first;
        _boite = t.motorise ? (_boite ?? Boite.manuelle) : null;
        final (min, max) = t.bornesPlaces;
        final p = int.tryParse(_places.text) ?? t.placesParDefaut;
        if (p < min || p > max) _places.text = '${t.placesParDefaut}';
        if (!t.motorise) {
          _immat.clear();
          _kilometrage.clear();
        }
      });

  /// Adresse -> latitude / longitude.
  Future<void> _localiser() async {
    FocusScope.of(context).unfocus();
    setState(() => _geoEnCours = _Geo.localiser);
    final r = await _geocodage.chercherAdresse(_adresse.text);
    if (!mounted) return;
    setState(() => _geoEnCours = null);
    if (r == null) {
      afficherMessage(context, _geocodage.derniereErreur ?? 'Adresse introuvable',
          erreur: true);
      return;
    }
    _latitude.text = r.latitude.toStringAsFixed(6);
    _longitude.text = r.longitude.toStringAsFixed(6);
    afficherMessage(context, 'Position trouvée : ${r.adresse}');
  }

  /// Latitude / longitude -> adresse.
  Future<void> _adresseDepuisPosition() async {
    final lat = _decimal(_latitude.text);
    final lng = _decimal(_longitude.text);
    if (lat == null || lng == null) {
      afficherMessage(context, 'Renseignez d\'abord la latitude et la longitude',
          erreur: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _geoEnCours = _Geo.inverse);
    final adresse = await _geocodage.adresseDepuisPosition(lat, lng);
    if (!mounted) return;
    setState(() => _geoEnCours = null);
    if (adresse == null) {
      afficherMessage(context, _geocodage.derniereErreur ?? 'Adresse introuvable',
          erreur: true);
      return;
    }
    _adresse.text = adresse;
  }

  /// Choix sur la carte : remplit les coordonnées et, si trouvée, l'adresse.
  Future<void> _choisirSurCarte() async {
    final r = await Navigator.push<PositionChoisie>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoisirPositionScreen(
          latitude: _decimal(_latitude.text),
          longitude: _decimal(_longitude.text),
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _latitude.text = r.latitude.toStringAsFixed(6);
      _longitude.text = r.longitude.toStringAsFixed(6);
      if (r.adresse != null) _adresse.text = r.adresse!;
    });
  }

  double? _decimal(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  /// Véhicule tel que saisi (enregistrement et fonctions IA).
  Vehicule _vehiculeSaisi() => Vehicule(
      id: widget.vehicule?.id,
      type: _type,
      marque: _marque.text,
      modele: _modele.text,
      annee: int.tryParse(_annee.text.trim()),
      couleur: _couleur.text,
      immatriculation: _type.motorise ? _immat.text : null,
      carburant: _carburant,
      boite: _type.motorise ? _boite : null,
      places: int.tryParse(_places.text.trim()) ?? _type.placesParDefaut,
      kilometrage: _type.motorise ? int.tryParse(_kilometrage.text.trim()) : null,
      prixParJour: Montants.depuisSaisie(_prix.text) ?? 0,
      caution: Montants.depuisSaisie(_caution.text) ?? 0,
      photos: _photos.text.split('\n'),
      latitude: _decimal(_latitude.text),
      longitude: _decimal(_longitude.text),
      adresse: _adresse.text,
      description: _description.text,
      statut: _statut,
      intervalleRevision: int.tryParse(_intervalle.text.trim()) ?? 10000,
      kmDerniereRevision: widget.vehicule?.kmDerniereRevision,
      majorationWeekend: _decimal(_weekend.text) ?? 0,
      majorationSaison: _decimal(_saison.text) ?? 0,
      remiseLongueDuree: _decimal(_remise.text) ?? 0,
      proprietaireId: widget.vehicule?.proprietaireId,
      creeLe: widget.vehicule?.creeLe,
    );

  /// Description générée par l'IA à partir de quelques mots.
  Future<void> _genererDescription() async {
    final mots = TextEditingController(text: _description.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Description par l\'IA'),
        content: TextField(
          controller: mots,
          maxLines: 3,
          decoration: decorationUi('Quelques mots (ex : « idéale pour la famille, clim »)',
              icone: Icons.edit_note),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Générer')),
        ],
      ),
    );
    final texte = mots.text;
    mots.dispose();
    if (ok != true || !mounted) return;
    setState(() => _iaEnCours = true);
    try {
      _description.text = await _ia.genererDescription(_vehiculeSaisi(), texte);
    } on IaException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _iaEnCours = false);
    }
  }

  /// Fourchette de prix proposée ; « Appliquer » prend le milieu.
  Future<void> _estimerPrix() async {
    setState(() => _iaEnCours = true);
    final e = await _ia.estimerPrix(_vehiculeSaisi());
    if (!mounted) return;
    setState(() => _iaEnCours = false);
    final milieu = ((e.min + e.max) / 2).roundToDouble();
    final appliquer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${e.min.toStringAsFixed(0)} – ${e.max.toStringAsFixed(0)} DT / jour'),
        content: Text('${e.justification}\n\n'
            '${e.parIa ? 'Estimation de l\'IA.' : 'IA indisponible : barème local.'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Fermer')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Appliquer ${milieu.toStringAsFixed(0)} DT'),
          ),
        ],
      ),
    );
    if (appliquer == true) _prix.text = milieu.toStringAsFixed(2);
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);
    if (!(_cle.currentState?.validate() ?? false)) return;
    final vehicule = _vehiculeSaisi();
    setState(() => _enregistrement = true);
    final erreur = await _repo.enregistrerVehicule(vehicule);
    if (!mounted) return;
    if (erreur != null) {
      setState(() {
        _enregistrement = false;
        _erreur = erreur;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  String? _entier(String? v, {required int min, required int max, bool obligatoire = true}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return obligatoire ? 'Champ obligatoire' : null;
    final n = int.tryParse(t);
    if (n == null || n < min || n > max) return 'Entre $min et $max';
    return null;
  }

  String? _pourcentage(String? v, double max) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final d = _decimal(t);
    if (d == null || d < 0 || d > max) return '0 à ${max.toStringAsFixed(0)}';
    return null;
  }

  String? _coordonnee(String? v, double limite) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final d = _decimal(t);
    if (d == null || d < -limite || d > limite) return 'Valeur entre -$limite et $limite';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (minPlaces, maxPlaces) = _type.bornesPlaces;
    return EcranModule(
      titre: _modeEdition ? 'Modifier le véhicule' : 'Nouveau véhicule',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<TypeVehicule>(
              segments: [
                for (final t in TypeVehicule.values)
                  ButtonSegment(value: t, label: Text(t.libelle), icon: Icon(t.icone)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _choisirType(s.first),
            ),
            const SizedBox(height: 20),
            _section('Identification'),
            ChampTexte(
              controller: _marque,
              label: 'Marque',
              icone: _type.icone,
              capitalisation: TextCapitalization.words,
              validateur: (v) => Validators.requis(v, champ: 'La marque'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _modele,
              label: 'Modèle',
              icone: Icons.label_outline,
              capitalisation: TextCapitalization.words,
              validateur: (v) => Validators.requis(v, champ: 'Le modèle'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _annee,
                    label: 'Année',
                    icone: Icons.calendar_month_outlined,
                    clavier: TextInputType.number,
                    validateur: (v) => _entier(v,
                        min: 1950, max: DateTime.now().year + 1, obligatoire: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChampTexte(
                    controller: _couleur,
                    label: 'Couleur',
                    icone: Icons.palette_outlined,
                    capitalisation: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
            if (_type.motorise) ...[
              const SizedBox(height: 14),
              ChampTexte(
                controller: _immat,
                label: 'Immatriculation (ex : 215 TU 4587)',
                icone: Icons.badge_outlined,
                capitalisation: TextCapitalization.characters,
                validateur: (v) => Validators.requis(v, champ: 'L\'immatriculation'),
              ),
            ],
            const SizedBox(height: 20),
            _section('Caractéristiques'),
            ChampChoix<Carburant>(
              label: 'Motorisation',
              icone: Icons.local_gas_station_outlined,
              valeur: _carburant,
              items: [
                for (final c in _type.carburants)
                  DropdownMenuItem(value: c, child: Text(c.libelle)),
              ],
              onChange: (c) => setState(() => _carburant = c ?? _carburant),
            ),
            if (_type.motorise) ...[
              const SizedBox(height: 14),
              ChampChoix<Boite>(
                label: 'Boîte de vitesses',
                icone: Icons.settings_outlined,
                valeur: _boite,
                items: [
                  for (final b in Boite.values)
                    DropdownMenuItem(value: b, child: Text(b.libelle)),
                ],
                onChange: (b) => setState(() => _boite = b),
              ),
            ],
            const SizedBox(height: 14),
            ChampTexte(
              controller: _places,
              label: 'Places ($minPlaces à $maxPlaces)',
              icone: Icons.event_seat_outlined,
              clavier: TextInputType.number,
              validateur: (v) => _entier(v, min: minPlaces, max: maxPlaces),
            ),
            if (_type.motorise) ...[
              const SizedBox(height: 14),
              ChampTexte(
                controller: _kilometrage,
                label: 'Kilométrage actuel (km)',
                icone: Icons.speed_outlined,
                clavier: TextInputType.number,
                validateur: (v) =>
                    _entier(v, min: 0, max: 2000000, obligatoire: false),
              ),
              const SizedBox(height: 14),
              ChampTexte(
                controller: _intervalle,
                label: 'Révision tous les … km',
                icone: Icons.build_outlined,
                clavier: TextInputType.number,
                validateur: (v) => _entier(v, min: 500, max: 100000),
              ),
            ],
            const SizedBox(height: 20),
            _section('Tarifs'),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _prix,
                    label: 'Prix / jour (DT)',
                    icone: Icons.payments_outlined,
                    clavier: const TextInputType.numberWithOptions(decimal: true),
                    validateur: (v) => Montants.valider(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChampTexte(
                    controller: _caution,
                    label: 'Caution (DT)',
                    icone: Icons.shield_outlined,
                    clavier: const TextInputType.numberWithOptions(decimal: true),
                    validateur: (v) => Montants.valider(v, obligatoire: false),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _iaEnCours ? null : _estimerPrix,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Estimer un prix juste'),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Tarification dynamique (%) : majoration le week-end, en juillet-août, '
                'et remise à partir de 7 jours.',
                style: TextStyle(color: AppColors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _weekend,
                    label: 'Week-end',
                    clavier: TextInputType.number,
                    validateur: (v) => _pourcentage(v, 200),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChampTexte(
                    controller: _saison,
                    label: 'Été',
                    clavier: TextInputType.number,
                    validateur: (v) => _pourcentage(v, 200),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChampTexte(
                    controller: _remise,
                    label: 'Remise',
                    clavier: TextInputType.number,
                    validateur: (v) => _pourcentage(v, 90),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section('Emplacement'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _adresse,
                    label: 'Lieu de prise en charge',
                    icone: Icons.place_outlined,
                    capitalisation: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _boutonGeo(
                    action: _Geo.localiser,
                    icone: Icons.travel_explore,
                    libelle: 'Localiser',
                    onPressed: _localiser,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _latitude,
                    label: 'Latitude',
                    clavier: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validateur: (v) => _coordonnee(v, 90),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChampTexte(
                    controller: _longitude,
                    label: 'Longitude',
                    clavier: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validateur: (v) => _coordonnee(v, 180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _boutonGeo(
                  action: _Geo.inverse,
                  icone: Icons.pin_drop_outlined,
                  libelle: 'Adresse depuis la position',
                  onPressed: _adresseDepuisPosition,
                ),
                OutlinedButton.icon(
                  onPressed: _geoEnCours == null ? _choisirSurCarte : null,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Choisir sur la carte'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section('Présentation'),
            ChampTexte(
              controller: _photos,
              label: 'Photos (une URL ou un asset par ligne)',
              icone: Icons.photo_library_outlined,
              clavier: TextInputType.multiline,
              lignes: 3,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _description,
              label: 'Description',
              icone: Icons.notes,
              clavier: TextInputType.multiline,
              lignes: 3,
              capitalisation: TextCapitalization.sentences,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _iaEnCours ? null : _genererDescription,
                icon: _iaEnCours
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Rédiger avec l\'IA'),
              ),
            ),
            const SizedBox(height: 14),
            ChampChoix<StatutVehicule>(
              label: 'Statut',
              icone: Icons.toggle_on_outlined,
              valeur: _statut,
              items: [
                for (final s in StatutVehicule.values)
                  DropdownMenuItem(value: s, child: Text(s.libelle)),
              ],
              onChange: (s) => setState(() => _statut = s ?? _statut),
            ),
            const SizedBox(height: 24),
            if (_erreur != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFBE3E0),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_erreur!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            BoutonPrincipal(
              libelle: _modeEdition ? 'Enregistrer les modifications' : 'Ajouter le véhicule',
              icone: Icons.check,
              onPressed: _enregistrement ? null : _enregistrer,
            ),
            const SizedBox(height: 12),
            BoutonSecondaire(
              libelle: 'Annuler',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton de géocodage : indicateur de chargement pendant son propre appel,
  /// désactivé pendant tout autre appel.
  Widget _boutonGeo({
    required _Geo action,
    required IconData icone,
    required String libelle,
    required VoidCallback onPressed,
  }) {
    final enCours = _geoEnCours == action;
    return OutlinedButton.icon(
      onPressed: _geoEnCours == null ? onPressed : null,
      icon: enCours
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icone),
      label: Text(libelle),
    );
  }

  Widget _section(String titre) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(titre.toUpperCase(),
            style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800)),
      );
}

/// Actions de géocodage du formulaire.
enum _Geo { localiser, inverse }
