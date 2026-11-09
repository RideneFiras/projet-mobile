import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_ia_service.dart';
import '../hebergement_repository.dart';
import '../models/hebergement.dart';

/// Ajout ou modification d'un établissement d'hébergement. Renvoie true si enregistré.
/// La note moyenne n'est pas saisie : elle vient des avis du forum.
class HebergementFormScreen extends StatefulWidget {
  final Hebergement? hebergement;

  const HebergementFormScreen({super.key, this.hebergement});

  @override
  State<HebergementFormScreen> createState() => _HebergementFormScreenState();
}

class _HebergementFormScreenState extends State<HebergementFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = HebergementRepository();
  late final TextEditingController _nom;
  late final TextEditingController _adresse;
  late final TextEditingController _ville;
  late final TextEditingController _prix;
  late final TextEditingController _capacite;
  late final TextEditingController _chambres;
  late final TextEditingController _telephone;
  late final TextEditingController _arrivee;
  late final TextEditingController _depart;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _photos;
  late final TextEditingController _description;
  late final TextEditingController _regles;
  late final TextEditingController _superficie;
  late final TextEditingController _weekend;
  late final TextEditingController _saison;
  late final TextEditingController _remise;
  final _ia = HebergementIaService();
  bool _iaEnCours = false;
  late TypeHebergement _type;
  int? _etoiles;
  late Set<Equipement> _equipements;
  late StatutHebergement _statut;
  String? _erreur;
  bool _enregistrement = false;

  bool get _modeEdition => widget.hebergement != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hebergement;
    String nombre(double? d) => d == null ? '' : '$d';
    _type = h?.type ?? TypeHebergement.hotel;
    _etoiles = h?.etoiles;
    _equipements = {...?h?.equipements};
    _statut = h?.statut ?? StatutHebergement.actif;
    _nom = TextEditingController(text: h?.nom ?? '');
    _adresse = TextEditingController(text: h?.adresse ?? '');
    _ville = TextEditingController(text: h?.ville ?? '');
    _prix = TextEditingController(text: h == null ? '' : h.prixParNuit.toStringAsFixed(2));
    _capacite = TextEditingController(text: '${h?.capacite ?? 2}');
    _chambres = TextEditingController(text: '${h?.nbChambres ?? 1}');
    _telephone = TextEditingController(text: h?.telephone ?? '');
    _arrivee = TextEditingController(text: h?.heureArrivee ?? '15:00');
    _depart = TextEditingController(text: h?.heureDepart ?? '11:00');
    _latitude = TextEditingController(text: nombre(h?.latitude));
    _longitude = TextEditingController(text: nombre(h?.longitude));
    _photos = TextEditingController(text: (h?.photos ?? const []).join('\n'));
    _description = TextEditingController(text: h?.description ?? '');
    _regles = TextEditingController(text: h?.regles ?? '');
    _superficie = TextEditingController(text: h?.superficie?.toStringAsFixed(0) ?? '');
    String pourcent(double? x) => (x ?? 0).toStringAsFixed(0);
    _weekend = TextEditingController(text: pourcent(h?.majorationWeekend));
    _saison = TextEditingController(text: pourcent(h?.majorationSaison));
    _remise = TextEditingController(text: pourcent(h?.remiseLongueDuree));
  }

  @override
  void dispose() {
    for (final c in [
      _nom, _adresse, _ville, _prix, _capacite, _chambres, _telephone,
      _arrivee, _depart, _latitude, _longitude, _photos, _description,
      _regles, _superficie, _weekend, _saison, _remise,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _decimal(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  /// Établissement tel que saisi (enregistrement et fonctions IA).
  /// Capacité et chambres non valides -> valeurs par défaut (seule l'IA s'en sert avant validation).
  Hebergement _saisi() => Hebergement(
      id: widget.hebergement?.id,
      nom: _nom.text,
      type: _type,
      description: _description.text,
      adresse: _adresse.text,
      ville: _ville.text,
      latitude: _decimal(_latitude.text),
      longitude: _decimal(_longitude.text),
      etoiles: _type.classable ? _etoiles : null,
      prixParNuit: Montants.depuisSaisie(_prix.text) ?? 0,
      capacite: int.tryParse(_capacite.text.trim()) ?? 2,
      nbChambres: int.tryParse(_chambres.text.trim()) ?? 1,
      regles: _regles.text,
      superficie: _decimal(_superficie.text),
      majorationWeekend: _decimal(_weekend.text) ?? 0,
      majorationSaison: _decimal(_saison.text) ?? 0,
      remiseLongueDuree: _decimal(_remise.text) ?? 0,
      proprietaireId: widget.hebergement?.proprietaireId,
      // Ordre de l'énumération : affichage stable d'un établissement à l'autre.
      equipements: [for (final e in Equipement.values) if (_equipements.contains(e)) e],
      photos: _photos.text.split('\n'),
      telephone: _telephone.text,
      heureArrivee: _arrivee.text.trim(),
      heureDepart: _depart.text.trim(),
      statut: _statut,
      creeLe: widget.hebergement?.creeLe,
    );

  Future<void> _genererDescription() async {
    final mots = TextEditingController(text: _description.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Description par l\'IA'),
        content: TextField(
          controller: mots,
          maxLines: 3,
          decoration: decorationUi('Quelques mots (ex : « maison près de la mer »)',
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
      _description.text = await _ia.genererDescription(_saisi(), texte);
    } on IaException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _iaEnCours = false);
    }
  }

  Future<void> _estimerPrix() async {
    setState(() => _iaEnCours = true);
    final e = await _ia.estimerPrixNuit(_saisi());
    if (!mounted) return;
    setState(() => _iaEnCours = false);
    final milieu = ((e.min + e.max) / 2).roundToDouble();
    final appliquer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${e.min.toStringAsFixed(0)} – ${e.max.toStringAsFixed(0)} DT / nuit'),
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
    final h = _saisi();
    setState(() => _enregistrement = true);
    final erreur = await _repo.enregistrerHebergement(h);
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

  String? _pourcentage(String? v, double max) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final d = _decimal(t);
    if (d == null || d < 0 || d > max) return '0 à ${max.toStringAsFixed(0)}';
    return null;
  }

  String? _entier(String? v, int min, int max) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < min || n > max) return 'Entre $min et $max';
    return null;
  }

  String? _heure(String? v) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v?.trim() ?? '')
          ? null
          : 'Format HH:MM';

  String? _coordonnee(String? v, double limite) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final d = _decimal(t);
    if (d == null || d < -limite || d > limite) return 'Entre -$limite et $limite';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier l\'établissement' : 'Nouvel établissement',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Identité'),
            ChampTexte(
              controller: _nom,
              label: 'Nom de l\'établissement',
              icone: Icons.bed_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) => Validators.requis(v, champ: 'Le nom'),
            ),
            const SizedBox(height: 14),
            ChampChoix<TypeHebergement>(
              label: 'Type',
              icone: Icons.category_outlined,
              valeur: _type,
              items: [
                for (final t in TypeHebergement.values)
                  DropdownMenuItem(value: t, child: Text(t.libelle)),
              ],
              onChange: (t) => setState(() {
                _type = t ?? _type;
                if (!_type.classable) _etoiles = null;
              }),
            ),
            if (_type.classable) ...[
              const SizedBox(height: 14),
              _choixEtoiles(),
            ],
            const SizedBox(height: 20),
            _section('Adresse'),
            ChampTexte(
              controller: _adresse,
              label: 'Adresse',
              icone: Icons.place_outlined,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) => Validators.requis(v, champ: 'L\'adresse'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _ville,
              label: 'Ville',
              icone: Icons.location_city_outlined,
              capitalisation: TextCapitalization.words,
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
            const SizedBox(height: 20),
            _section('Capacité et tarif'),
            ChampTexte(
              controller: _prix,
              label: 'Prix par nuit et par chambre (DT)',
              icone: Icons.payments_outlined,
              clavier: const TextInputType.numberWithOptions(decimal: true),
              validateur: (v) => Montants.valider(v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _iaEnCours ? null : _estimerPrix,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Estimer un prix concurrentiel'),
              ),
            ),
            const Text('Tarification dynamique (%) : week-end, juillet-août, '
                'remise à partir de 7 nuits.',
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
            const SizedBox(height: 14),
            ChampTexte(
              controller: _superficie,
              label: 'Surface (m², facultatif)',
              icone: Icons.square_foot,
              clavier: const TextInputType.numberWithOptions(decimal: true),
              validateur: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final d = _decimal(t);
                return (d == null || d <= 0 || d > 10000) ? 'Surface invalide' : null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _capacite,
                    label: 'Pers. / chambre',
                    icone: Icons.group_outlined,
                    clavier: TextInputType.number,
                    validateur: (v) => _entier(v, 1, 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChampTexte(
                    controller: _chambres,
                    label: 'Chambres',
                    icone: Icons.meeting_room_outlined,
                    clavier: TextInputType.number,
                    validateur: (v) => _entier(v, 1, 500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChampTexte(
                    controller: _arrivee,
                    label: 'Arrivée dès',
                    icone: Icons.login,
                    clavier: TextInputType.datetime,
                    validateur: _heure,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChampTexte(
                    controller: _depart,
                    label: 'Départ avant',
                    icone: Icons.logout,
                    clavier: TextInputType.datetime,
                    validateur: _heure,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _telephone,
              label: 'Téléphone (facultatif)',
              icone: Icons.phone_outlined,
              clavier: TextInputType.phone,
              validateur: (v) =>
                  (v == null || v.trim().isEmpty) ? null : Validators.telephone(v),
            ),
            const SizedBox(height: 20),
            _section('Équipements'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in Equipement.values)
                  FilterChip(
                    avatar: Icon(e.icone,
                        size: 18,
                        color: _equipements.contains(e) ? AppColors.white : AppColors.teal),
                    label: Text(e.libelle),
                    selected: _equipements.contains(e),
                    showCheckmark: false,
                    selectedColor: AppColors.teal,
                    backgroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _equipements.contains(e) ? AppColors.white : AppColors.navy),
                    onSelected: (oui) => setState(() {
                      if (oui) {
                        _equipements.add(e);
                      } else {
                        _equipements.remove(e);
                      }
                    }),
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
              lignes: 4,
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
                label: const Text('Rédiger avec l\'IA (SEO)'),
              ),
            ),
            const SizedBox(height: 8),
            ChampTexte(
              controller: _regles,
              label: 'Règles de la maison (animaux, fêtes, tabac…)',
              icone: Icons.rule,
              clavier: TextInputType.multiline,
              lignes: 3,
              capitalisation: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            ChampChoix<StatutHebergement>(
              label: 'Statut',
              icone: Icons.toggle_on_outlined,
              valeur: _statut,
              items: [
                for (final s in StatutHebergement.values)
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
              libelle: _modeEdition ? 'Enregistrer les modifications' : 'Ajouter l\'établissement',
              icone: Icons.check,
              onPressed: _enregistrement ? null : _enregistrer,
            ),
            const SizedBox(height: 12),
            BoutonSecondaire(
              libelle: 'Annuler',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les séjours déjà réservés sont conservés si vous modifiez les informations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Étoiles cliquables ; un second appui sur la même étoile retire le classement.
  Widget _choixEtoiles() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Text('Classement',
                style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600)),
            const Spacer(),
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '$i étoile${i > 1 ? 's' : ''}',
                icon: Icon(
                  i <= (_etoiles ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.orange,
                ),
                onPressed: () => setState(() => _etoiles = _etoiles == i ? null : i),
              ),
          ],
        ),
      );

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
