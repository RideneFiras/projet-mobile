import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/trajet_transport.dart';
import '../models/transporteur.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_routes.dart';
import '../transport_widgets.dart';

/// Création ou modification d'un trajet. Le statut ne se change pas ici :
/// il se modifie depuis la liste des trajets, selon les transitions autorisées.
class TrajetFormScreen extends StatefulWidget {
  final int utilisateurId;
  final TrajetTransport? trajet;

  const TrajetFormScreen({super.key, required this.utilisateurId, this.trajet});

  @override
  State<TrajetFormScreen> createState() => _TrajetFormScreenState();
}

class _TrajetFormScreenState extends State<TrajetFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = TransportRepository();
  final _depart = TextEditingController();
  final _adresseDepart = TextEditingController();
  final _destination = TextEditingController();
  final _adresseArrivee = TextEditingController();
  final _heureDepart = TextEditingController();
  final _heureArrivee = TextEditingController();
  final _prix = TextEditingController();
  final _places = TextEditingController();
  final _arrets = TextEditingController();
  DateTime? _jourDepart;
  DateTime? _jourArrivee;
  String _type = Transporteur.types.first;
  String? _erreurDate;
  int? _transporteurId;
  bool _charge = false;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    final t = widget.trajet;
    final maintenant = DateTime.now();
    final depart = t?.dateDepart ??
        DateTime(maintenant.year, maintenant.month, maintenant.day + 1, 9);
    final arrivee = t?.dateArriveeEstimee ?? depart.add(const Duration(hours: 2));
    _depart.text = t?.villeDepart ?? '';
    _adresseDepart.text = t?.adresseDepart ?? '';
    _destination.text = t?.destination ?? '';
    _adresseArrivee.text = t?.adresseArrivee ?? '';
    _jourDepart = dateJour(depart);
    _jourArrivee = dateJour(arrivee);
    _heureDepart.text = TransportFormat.heure(depart);
    _heureArrivee.text = TransportFormat.heure(arrivee);
    _prix.text = t == null ? '' : t.prixParPersonne.toStringAsFixed(2);
    _places.text = '${t?.placesTotales ?? 4}';
    _arrets.text = t?.arrets ?? '';
    _type = t?.typeTransport ?? Transporteur.types.first;
    if (t != null) {
      _transporteurId = t.transporteurId;
      _charge = true;
    } else {
      _chargerProfil();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _depart,
      _adresseDepart,
      _destination,
      _adresseArrivee,
      _heureDepart,
      _heureArrivee,
      _prix,
      _places,
      _arrets,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerProfil() async {
    final profil = await _repo.profilDe(widget.utilisateurId);
    if (!mounted) return;
    setState(() {
      _transporteurId = profil?.id;
      _charge = true;
    });
  }

  Future<void> _enregistrer() async {
    final uid = widget.utilisateurId;
    final transporteurId = widget.trajet?.transporteurId ?? _transporteurId;
    final erreurDate = TransportFormat.validerDateFuture(_jourDepart) ??
        (_jourArrivee == null ? "Date d'arrivée obligatoire" : null);
    setState(() => _erreurDate = erreurDate);
    if (!_cle.currentState!.validate() || erreurDate != null || transporteurId == null) {
      return;
    }
    final dep = TransportFormat.combiner(_jourDepart, _heureDepart.text);
    final arr = TransportFormat.combiner(_jourArrivee, _heureArrivee.text);
    final centimes = TransportFormat.parserMontant(_prix.text);
    final places = TransportFormat.parserEntier(_places.text);
    if (dep == null || arr == null || centimes == null || places == null) return;
    if (!arr.isAfter(dep)) {
      afficherMessage(context, "L'arrivée doit être après le départ", erreur: true);
      return;
    }
    final t = widget.trajet;
    if (t == null && dep.isBefore(DateTime.now())) {
      afficherMessage(context, "L'heure de départ est déjà passée", erreur: true);
      return;
    }
    setState(() => _occupe = true);
    final trajet = TrajetTransport(
      id: t?.id,
      transporteurId: transporteurId,
      villeDepart: _depart.text,
      destination: _destination.text,
      adresseDepart: _adresseDepart.text,
      adresseArrivee: _adresseArrivee.text,
      dateDepart: dep,
      dateArriveeEstimee: arr,
      prixParPersonne: TransportFormat.depuisCentimes(centimes),
      placesTotales: places,
      typeTransport: _type,
      arrets: _arrets.text,
      statut: t?.statut ?? StatutTrajet.planifie,
      creeLe: t?.creeLe ?? DateTime.now(),
    );
    final String? erreur = t == null
        ? await _repo.creerTrajet(trajet, uid)
        : await _repo.modifierTrajet(trajet, uid);
    if (!mounted) return;
    setState(() => _occupe = false);
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    afficherMessage(context, t == null ? 'Trajet ajouté' : 'Trajet modifié');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trajet;
    final titre = t == null ? 'Nouveau trajet' : 'Modifier le trajet';
    if (!_charge) {
      return EcranModule(
        titre: titre,
        corps: const Center(child: CircularProgressIndicator()),
      );
    }
    if (t == null && _transporteurId == null) {
      return EcranModule(
        titre: titre,
        corps: EtatVideModule(
          icone: Icons.person_add_alt_1_outlined,
          titre: "Créez d'abord votre profil",
          message: 'Un trajet est rattaché à votre profil transporteur.',
          libelleAction: 'Créer mon profil',
          onAction: () => Navigator.pushReplacementNamed(
              context, TransportRoutes.transporteurs),
        ),
      );
    }
    return EcranModule(
      titre: titre,
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (t != null) ...[
              Row(
                children: [
                  const Text('Statut : ',
                      style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600)),
                  Pastille(libelle: t.statut.libelle, valeur: t.statut.valeur),
                ],
              ),
              const SizedBox(height: 14),
            ],
            ChampTexte(
              controller: _depart,
              label: 'Ville de départ',
              icone: Icons.trip_origin,
              capitalisation: TextCapitalization.words,
              validateur: (v) => TransportFormat.validerVille(v, champ: 'La ville de départ'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _adresseDepart,
              label: 'Adresse exacte de départ (facultatif)',
              icone: Icons.place_outlined,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _destination,
              label: "Ville d'arrivée",
              icone: Icons.flag_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) =>
                  TransportFormat.validerVille(v, champ: "La ville d'arrivée") ??
                  TransportFormat.validerTrajet(_depart.text, v),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _adresseArrivee,
              label: "Adresse exacte d'arrivée (facultatif)",
              icone: Icons.place_outlined,
            ),
            const SizedBox(height: 14),
            ChampDate(
              label: 'Date de départ',
              valeur: _jourDepart,
              erreur: _erreurDate,
              premiereDate: DateTime.now(),
              onChoisie: (d) => setState(() {
                _jourDepart = d;
                _erreurDate = null;
              }),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _heureDepart,
              label: 'Heure de départ (HH:mm)',
              icone: Icons.schedule,
              clavier: TextInputType.datetime,
              validateur: TransportFormat.validerHeure,
            ),
            const SizedBox(height: 14),
            ChampDate(
              label: "Date d'arrivée estimée",
              valeur: _jourArrivee,
              premiereDate: DateTime.now(),
              onChoisie: (d) => setState(() => _jourArrivee = d),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _heureArrivee,
              label: "Heure d'arrivée estimée (HH:mm)",
              icone: Icons.schedule,
              clavier: TextInputType.datetime,
              validateur: TransportFormat.validerHeure,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _prix,
              label: 'Prix par personne (DT)',
              icone: Icons.payments_outlined,
              clavier: const TextInputType.numberWithOptions(decimal: true),
              validateur: (v) => TransportFormat.validerMontant(v),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _places,
              label: 'Places proposées',
              icone: Icons.airline_seat_recline_normal,
              clavier: TextInputType.number,
              validateur: (v) =>
                  TransportFormat.validerEntier(v, champ: 'Le nombre de places', max: 99),
            ),
            const SizedBox(height: 14),
            ChampChoix<String>(
              label: 'Type de transport',
              icone: Icons.directions_bus_outlined,
              valeur: _type,
              items: [
                for (final s in Transporteur.types)
                  DropdownMenuItem<String>(value: s, child: Text(Transporteur.libelleType(s))),
              ],
              onChange: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _arrets,
              label: 'Arrêts intermédiaires (facultatif)',
              icone: Icons.more_horiz,
              lignes: 2,
            ),
            const SizedBox(height: 24),
            BoutonPrincipal(
              libelle: 'Enregistrer',
              icone: Icons.save_outlined,
              onPressed: _occupe ? null : _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
