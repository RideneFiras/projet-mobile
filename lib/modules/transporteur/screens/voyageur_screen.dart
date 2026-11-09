import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/trajet_transport.dart';
import '../models/transporteur.dart';
import '../transport_actualisation.dart';
import '../transport_format.dart';
import '../transport_itineraire_sheet.dart';
import '../transport_repository.dart';
import '../transport_routes.dart';
import '../transport_widgets.dart';
import 'commande_form_screen.dart';

/// Côté voyageur : recherche d'un trajet planifié, tri, pagination, puis demande.
/// La demande est proposée automatiquement aux transporteurs compatibles, qui acceptent ou refusent.
class VoyageurScreen extends StatefulWidget {
  const VoyageurScreen({super.key});

  @override
  State<VoyageurScreen> createState() => _VoyageurScreenState();
}

class _VoyageurScreenState extends State<VoyageurScreen> {
  final _repo = TransportRepository();
  final _depart = TextEditingController();
  final _arrivee = TextEditingController();
  DateTime? _jour;
  TriTrajet _tri = TriTrajet.dateDepart;
  int _page = 1;

  /// Critères de la dernière recherche : le tri et la pagination les réutilisent,
  /// même si l'utilisateur modifie les champs entre-temps.
  ({String depart, String arrivee, DateTime? jour})? _criteres;
  Future<PageTrajets>? _resultats;
  ActualisationAuto? _actu;

  @override
  void initState() {
    super.initState();
    _actu = ActualisationAuto(rafraichir: _charger)..demarrer();
  }

  @override
  void dispose() {
    _actu?.arreter();
    _depart.dispose();
    _arrivee.dispose();
    super.dispose();
  }

  void _rechercher() {
    _page = 1;
    _criteres = (depart: _depart.text, arrivee: _arrivee.text, jour: _jour);
    _charger();
  }

  void _charger() {
    final c = _criteres;
    if (c == null) return;
    setState(() {
      _resultats = _repo.rechercherTrajets(
        depart: c.depart,
        arrivee: c.arrivee,
        jour: c.jour,
        tri: _tri,
        page: _page,
      );
    });
  }

  void _allerPage(int page) {
    _page = page;
    _charger();
  }

  void _changerTri(TriTrajet? tri) {
    if (tri == null) return;
    _tri = tri;
    _page = 1;
    _charger();
  }

  Future<void> _demander({TrajetTransport? trajet}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommandeFormScreen(
          departInitial: trajet?.villeDepart ?? _depart.text,
          arriveeInitiale: trajet?.destination ?? _arrivee.text,
          dateInitiale: trajet?.dateDepart ?? _jour,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Transport',
      actions: [
        IconButton(
          tooltip: 'Mes commandes',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => Navigator.pushNamed(context, TransportRoutes.mesCommandes),
        ),
      ],
      corps: CorpsListeTransport(
        onRefresh: () async {
          _charger();
        },
        entete: const EnTeteModule(
          titre: 'Trouver un trajet',
          sousTitre:
              'Recherchez un trajet, ou envoyez votre demande : les transporteurs compatibles sont prévenus.',
          icone: Icons.directions_bus_outlined,
        ),
        enfants: [
          CarteTransport(child: _formulaire()),
          _resultatsWidget(),
        ],
      ),
    );
  }

  Widget _formulaire() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChampTexte(
            controller: _depart,
            label: 'Ville de départ',
            icone: Icons.trip_origin,
            capitalisation: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          ChampTexte(
            controller: _arrivee,
            label: "Ville d'arrivée",
            icone: Icons.flag_outlined,
            capitalisation: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          ChampDate(
            label: 'Date (facultatif)',
            valeur: _jour,
            premiereDate: DateTime.now(),
            onChoisie: (d) => setState(() => _jour = d),
          ),
          if (_jour != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _jour = null),
                child: const Text('Effacer la date'),
              ),
            ),
          const SizedBox(height: 8),
          BoutonPrincipal(
            libelle: 'Rechercher',
            icone: Icons.search,
            onPressed: _rechercher,
          ),
        ],
      );

  Widget _resultatsWidget() {
    final f = _resultats;
    if (f == null) {
      return const EtatVideModule(
        icone: Icons.search,
        titre: 'Lancez une recherche',
        message: 'Indiquez une ville de départ, une destination ou une date.',
      );
    }
    return FutureBuilder<PageTrajets>(
      future: f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const EtatVideModule(
            icone: Icons.error_outline,
            titre: 'Recherche impossible',
            message: 'Réessayez dans un instant.',
          );
        }
        final page = snap.data!;
        if (page.total == 0) {
          return EtatVideModule(
            icone: Icons.search_off,
            titre: 'Aucun trajet trouvé',
            message:
                'Envoyez tout de même votre demande : elle sera proposée aux transporteurs compatibles.',
            libelleAction: 'Envoyer une demande',
            onAction: () => _demander(),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChampChoix<TriTrajet>(
              label: 'Trier par',
              icone: Icons.sort,
              valeur: _tri,
              items: [
                for (final t in TriTrajet.values)
                  DropdownMenuItem(value: t, child: Text(t.libelle)),
              ],
              onChange: _changerTri,
            ),
            const SizedBox(height: 12),
            for (final t in page.trajets) _carte(t),
            _pagination(page),
          ],
        );
      },
    );
  }

  Widget _pagination(PageTrajets p) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: p.aPrecedente ? () => _allerPage(p.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${p.page} sur ${p.nombrePages} · ${p.total} trajet(s)',
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
          IconButton(
            tooltip: 'Page suivante',
            onPressed: p.aSuivante ? () => _allerPage(p.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );

  Widget _carte(TrajetTransport t) => CarteTransport(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LigneTrajet(depart: t.villeDepart, arrivee: t.destination),
            const SizedBox(height: 8),
            LigneInfo(
              icone: Icons.event_outlined,
              texte: '${dateCourte(t.dateDepart)} à ${TransportFormat.heure(t.dateDepart)}',
            ),
            const SizedBox(height: 4),
            LigneInfo(
              icone: Icons.payments_outlined,
              texte: '${TransportFormat.prix(t.prixParPersonne)} par personne · '
                  '${t.placesLibres} place(s) libre(s)',
            ),
            const SizedBox(height: 4),
            LigneInfo(
              icone: Icons.local_shipping_outlined,
              texte: '${t.nomTransporteur} · ${Transporteur.libelleType(t.typeTransport)}',
            ),
            const SizedBox(height: 12),
            BoutonSecondaire(
              libelle: 'Itinéraire',
              icone: Icons.route,
              onPressed: () => afficherItineraire(context, t),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _demander(trajet: t),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Demander ce trajet'),
              ),
            ),
          ],
        ),
      );
}
