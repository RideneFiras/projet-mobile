import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/itineraire.dart';
import '../models/offre_vol.dart';
import '../models/voyage.dart';
import '../models/voyage_vol.dart';
import '../voyage_ia_service.dart';
import '../voyage_itineraire_repository.dart';
import '../voyage_vol_repository.dart';
import 'voyage_form_screen.dart';

/// Fiche d'un voyage : vol choisi, budget estimé, itinéraire IA.
/// C'est le « hub » du voyage : les réservations des autres modules s'y rattachent.
class VoyageDetailScreen extends StatefulWidget {
  final Voyage voyage;

  const VoyageDetailScreen({super.key, required this.voyage});

  @override
  State<VoyageDetailScreen> createState() => _VoyageDetailScreenState();
}

class _VoyageDetailScreenState extends State<VoyageDetailScreen> {
  final _volRepo = VoyageVolRepository();
  final _itRepo = VoyageItineraireRepository();
  final _ia = VoyageIaService();

  (VoyageVol, OffreVol)? _vol;
  Itineraire? _itineraire;
  Confort _confort = Confort.confortable;
  bool _chargement = true;
  bool _generation = false;
  String? _erreur;

  Voyage get _v => widget.voyage;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final vol = await _volRepo.volDuVoyage(_v.id!);
    final it = await _itRepo.charger(_v.id!);
    if (!mounted) return;
    setState(() {
      _vol = vol;
      if (it != null) {
        _confort = it.$1;
        _itineraire = it.$2;
      }
      _chargement = false;
    });
  }

  Future<void> _modifier() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VoyageFormScreen(voyage: _v)),
    );
    // Le voyage affiché est périmé après modification : retour à la liste (qui recharge).
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _generer() async {
    setState(() {
      _generation = true;
      _erreur = null;
    });
    try {
      final it = await _ia.genererItineraire(voyage: _v, confort: _confort);
      await _itRepo.sauvegarder(_v.id!, _confort, it);
      if (!mounted) return;
      setState(() {
        _itineraire = it;
        _generation = false;
      });
    } on VoyageIaException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _generation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Une erreur est survenue. Réessayez.';
        _generation = false;
      });
    }
  }

  double get _billet => _vol?.$1.prix ?? _v.budget;
  double get _sejour => _confort.parJour * _v.duree;

  @override
  Widget build(BuildContext context) {
    final statut = _v.statutEffectif;
    return EcranModule(
      titre: 'Détail du voyage',
      actions: [
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _modifier,
        ),
      ],
      corps: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          EnTeteModule(
            titre: _v.titre,
            sousTitre: _v.destination,
            icone: Icons.flight_takeoff,
            indicateurs: [
              IndicateurEnTete(
                  valeur: '${_v.duree} j',
                  libelle: 'durée',
                  icone: Icons.event_outlined),
              IndicateurEnTete(
                  valeur: Montants.affiche(_billet),
                  libelle: 'billet',
                  icone: Icons.payments_outlined),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _carteVol(statut),
                const SizedBox(height: 20),
                const EnteteSection(titre: 'Budget estimé'),
                const SizedBox(height: 10),
                _carteBudget(),
                const SizedBox(height: 20),
                const EnteteSection(titre: 'Itinéraire par l\'IA'),
                const SizedBox(height: 10),
                _sectionIa(),
                const SizedBox(height: 20),
                const EnteteSection(titre: 'Réservations liées'),
                const SizedBox(height: 10),
                _reservations(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteVol(StatutVoyage statut) {
    final vol = _vol;
    return CarteModule(
      accent: couleursStatut(statut.valeur).$2,
      child: Column(
        children: [
          Row(
            children: [
              const Text('Mon vol',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Pastille(libelle: statut.libelle, valeur: statut.valeur),
            ],
          ),
          const SizedBox(height: 8),
          _Ligne(Icons.place_outlined, 'Destination', _v.destination),
          _Ligne(Icons.event_outlined, 'Dates', periode(_v.dateDebut, _v.dateFin)),
          if (vol != null) ...[
            _Ligne(Icons.airline_seat_recline_normal, 'Classe', vol.$1.classe.libelle),
            _Ligne(Icons.schedule, 'Durée du vol', vol.$2.dureeLibelle),
          ],
          _Ligne(Icons.confirmation_number_outlined,
              vol != null ? 'Prix du billet' : 'Budget', Montants.affiche(_billet)),
        ],
      ),
    );
  }

  Widget _carteBudget() {
    final total = _billet + _sejour;
    int part(double x) => x.round().clamp(1, 100000000).toInt();
    return CarteModule(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Niveau de séjour sur place',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in Confort.values)
                ChoiceChip(
                  label: Text(c.libelle),
                  selected: _confort == c,
                  onSelected: (_) => setState(() => _confort = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                      flex: part(_billet),
                      child: Container(color: AppColors.teal)),
                  Expanded(
                      flex: part(_sejour),
                      child: Container(color: AppColors.orange)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _legende(AppColors.teal, 'Billet d\'avion', _billet),
          _legende(AppColors.orange,
              'Séjour (${_confort.libelle}, ${Montants.affiche(_confort.parJour)}/jour)', _sejour),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Total estimé',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(Montants.affiche(total),
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Répartition du séjour',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 4),
          for (final (nom, taux) in repartitionSejour)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text('$nom  ·  ${(taux * 100).round()} %',
                      style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  Text(Montants.affiche(_sejour * taux),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _legende(Color couleur, String texte, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 14))),
          Text(Montants.affiche(montant),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionIa() {
    final it = _itineraire;
    return CarteModule(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (it == null && !_generation)
            const Text(
              'Générez un programme jour par jour pour votre destination, '
                  'adapté au niveau de séjour choisi ci-dessus.',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          if (_generation)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: 14),
                  Expanded(child: Text('Rédaction de votre itinéraire...')),
                ],
              ),
            ),
          if (_erreur != null) ...[
            const SizedBox(height: 8),
            Text(_erreur!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          if (it != null && !_generation) ...[
            for (final j in it.jours) _jour(j),
            if (it.conseil.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: AppColors.orangeText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(it.conseil,
                          style: const TextStyle(
                              color: AppColors.orangeText, fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          BoutonPrincipal(
            libelle: it == null ? 'Générer mon itinéraire' : 'Régénérer',
            icone: Icons.auto_awesome,
            onPressed: _generation ? null : _generer,
          ),
        ],
      ),
    );
  }

  Widget _jour(JourPlan j) {
    Widget moment(IconData icone, String texte) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jour ${j.jour} · ${j.titre}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          moment(Icons.wb_sunny_outlined, j.matin),
          moment(Icons.wb_twilight, j.apresMidi),
          moment(Icons.nights_stay_outlined, j.soir),
        ],
      ),
    );
  }

  Widget _reservations() {
    Widget ligne(IconData icone, String nom, String module) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, color: AppColors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(module,
                    style:
                    const TextStyle(color: AppColors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Pastille(libelle: 'Bientôt', valeur: 'en_attente'),
        ],
      ),
    );
    return CarteModule(
      child: Column(
        children: [
          ligne(Icons.directions_car_outlined, 'Location de voiture', 'Module Location'),
          const Divider(height: 8),
          ligne(Icons.hotel_outlined, 'Hébergement', 'Module Hébergement'),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String valeur;

  const _Ligne(this.icone, this.libelle, this.valeur);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: AppColors.grey),
          const SizedBox(width: 10),
          Text(libelle,
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(valeur,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
