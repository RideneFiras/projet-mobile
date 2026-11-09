import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../user/role.dart';
import '../../user/utilisateur.dart';
import '../models/mise_en_relation.dart';
import '../models/reservation_transport.dart';
import '../models/trajet_transport.dart';
import '../transport_actualisation.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';
import 'trajet_form_screen.dart';

/// Ordre d'affichage des trajets.
enum _Tri { dateCroissante, dateDecroissante, prixCroissant, placesLibres }

String _libelleTri(_Tri t) => switch (t) {
      _Tri.dateCroissante => 'Date (la plus proche)',
      _Tri.dateDecroissante => 'Date (la plus lointaine)',
      _Tri.prixCroissant => 'Prix (croissant)',
      _Tri.placesLibres => 'Places libres (décroissant)',
    };

/// Réservations du transporteur, en deux sections :
///  - « Trajets » : les trajets proposés, avec recherche, filtre, tri et actions ;
///  - « Réservations » : les passagers confirmés, avec prise en charge, annulation,
///    historique.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _cleTrajets = GlobalKey<_ListeTrajetsState>();
  bool _charge = false;
  Utilisateur? _utilisateur;
  int _section = 0; // 0 = trajets, 1 = réservations

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final u = await utilisateurAutorise(role: Role.transporter);
    if (!mounted) return;
    setState(() {
      _utilisateur = u;
      _charge = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const titre = 'Réservations';
    if (!_charge) {
      return const EcranModule(
        titre: titre,
        corps: Center(child: CircularProgressIndicator()),
      );
    }
    final id = _utilisateur?.id;
    if (id == null) {
      return const EcranModule(
        titre: titre,
        corps: EtatVideModule(
          icone: Icons.event_available_outlined,
          titre: 'Accès réservé',
          message: 'Cet écran est réservé aux comptes transporteur.',
        ),
      );
    }
    final selecteur = SelecteurSection(
      libelles: const ['Trajets', 'Réservations'],
      selection: _section,
      onChange: (i) => setState(() => _section = i),
    );
    final trajets = _section == 0;
    return EcranModule(
      titre: titre,
      boutonFlottant: trajets
          ? BoutonAjouterTransport(
              libelle: 'Nouveau trajet',
              onPressed: () => _cleTrajets.currentState?.ajouter(),
            )
          : null,
      corps: trajets
          ? _ListeTrajets(key: _cleTrajets, utilisateurId: id, selecteur: selecteur)
          : _ListeReservations(utilisateurId: id, selecteur: selecteur),
    );
  }
}

// ----------------------------------------------------------------------
// Section « Trajets »
// ----------------------------------------------------------------------

class _ListeTrajets extends StatefulWidget {
  final int utilisateurId;
  final Widget selecteur;

  const _ListeTrajets({super.key, required this.utilisateurId, required this.selecteur});

  @override
  State<_ListeTrajets> createState() => _ListeTrajetsState();
}

class _ListeTrajetsState extends State<_ListeTrajets> {
  final _repo = TransportRepository();
  final _recherche = TextEditingController();
  StatutTrajet? _statut;
  _Tri _tri = _Tri.dateCroissante;
  late Future<List<TrajetTransport>> _liste =
      _repo.trajetsDuTransporteur(widget.utilisateurId);
  ActualisationAuto? _actu;

  @override
  void initState() {
    super.initState();
    _actu = ActualisationAuto(rafraichir: _rafraichir)..demarrer();
  }

  void _rafraichir() {
    if (mounted) {
      setState(() => _liste = _repo.trajetsDuTransporteur(widget.utilisateurId));
    }
  }

  @override
  void dispose() {
    _actu?.arreter();
    _recherche.dispose();
    super.dispose();
  }

  void _recharger() =>
      setState(() => _liste = _repo.trajetsDuTransporteur(widget.utilisateurId));

  /// Ouvre le formulaire (ajout si [trajet] est nul), puis relit la liste.
  Future<void> ajouter([TrajetTransport? trajet]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrajetFormScreen(utilisateurId: widget.utilisateurId, trajet: trajet),
      ),
    );
    if (mounted) _recharger();
  }

  List<TrajetTransport> _filtrer(List<TrajetTransport> items) {
    final q = _recherche.text.trim().toLowerCase();
    final resultat = items.where((t) {
      if (_statut != null && t.statut != _statut) return false;
      if (q.isEmpty) return true;
      return t.villeDepart.toLowerCase().contains(q) ||
          t.destination.toLowerCase().contains(q) ||
          t.adresseDepart.toLowerCase().contains(q);
    }).toList();
    int comparer(TrajetTransport a, TrajetTransport b) => switch (_tri) {
          _Tri.dateCroissante => a.dateDepart.compareTo(b.dateDepart),
          _Tri.dateDecroissante => b.dateDepart.compareTo(a.dateDepart),
          _Tri.prixCroissant => a.prixParPersonne.compareTo(b.prixParPersonne),
          _Tri.placesLibres => b.placesLibres.compareTo(a.placesLibres),
        };
    resultat.sort(comparer);
    return resultat;
  }

  Future<void> _agir(String action, TrajetTransport t) async {
    if (action == 'modifier') {
      await ajouter(t);
    } else if (action == 'dupliquer') {
      await _dupliquer(t);
    } else if (action == 'demarrer') {
      await _changer(t, StatutTrajet.enCours);
    } else if (action == 'terminer') {
      await _changer(t, StatutTrajet.termine);
    } else if (action == 'annuler') {
      final ok = await confirmer(
        context,
        titre: 'Annuler ce trajet ?',
        message: 'Les réservations de ce trajet seront annulées et les voyageurs '
            'en garderont la trace dans leur historique.',
        action: 'Annuler le trajet',
      );
      if (ok && mounted) await _changer(t, StatutTrajet.annule);
    } else if (action == 'supprimer') {
      await _supprimer(t);
    }
  }

  Future<void> _changer(TrajetTransport t, StatutTrajet nouveau) async {
    final id = t.id;
    if (id == null) return;
    final erreur = await _repo.changerStatutTrajet(id, widget.utilisateurId, nouveau);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Statut : ${nouveau.libelle}',
        erreur: erreur != null);
    if (erreur == null) _recharger();
  }

  Future<void> _dupliquer(TrajetTransport t) async {
    final id = t.id;
    if (id == null) return;
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: aujourdhui.add(const Duration(days: 7)),
      firstDate: DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
      lastDate: DateTime(aujourdhui.year + 2),
    );
    if (choisie == null || !mounted) return;
    final erreur = await _repo.dupliquerTrajet(id, widget.utilisateurId, choisie);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Trajet copié au ${dateCourte(choisie)}',
        erreur: erreur != null);
    if (erreur == null) _recharger();
  }

  Future<void> _supprimer(TrajetTransport t) async {
    final id = t.id;
    if (id == null) return;
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce trajet ?',
      message: 'Cette action est définitive.',
    );
    if (!ok || !mounted) return;
    final erreur = await _repo.supprimerTrajet(id, widget.utilisateurId);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Trajet supprimé', erreur: erreur != null);
    if (erreur == null) _recharger();
  }

  List<PopupMenuEntry<String>> _menu(TrajetTransport t) => [
        if (t.statut == StatutTrajet.planifie)
          const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
        const PopupMenuItem(value: 'dupliquer', child: Text('Dupliquer à une autre date')),
        if (t.statut == StatutTrajet.planifie)
          const PopupMenuItem(value: 'demarrer', child: Text('Démarrer le trajet')),
        if (t.statut == StatutTrajet.enCours)
          const PopupMenuItem(value: 'terminer', child: Text('Marquer comme terminé')),
        if (t.statut == StatutTrajet.planifie || t.statut == StatutTrajet.enCours)
          const PopupMenuItem(value: 'annuler', child: Text('Annuler le trajet')),
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
      ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrajetTransport>>(
      future: _liste,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tous = snap.data ?? const <TrajetTransport>[];
        final visibles = _filtrer(tous);
        final maintenant = DateTime.now();
        final planifiesAVenir = tous
            .where((t) =>
                t.statut == StatutTrajet.planifie && !t.dateDepart.isBefore(maintenant))
            .length;
        return CorpsListeTransport(
          onRefresh: () async => _recharger(),
          selecteur: widget.selecteur,
          entete: EnTeteModule(
            titre: 'Mes trajets',
            sousTitre: 'Trajets que vous proposez aux voyageurs.',
            icone: Icons.alt_route,
            indicateurs: [
              IndicateurEnTete(
                  valeur: '${tous.length}', libelle: 'trajets', icone: Icons.alt_route),
              IndicateurEnTete(
                  valeur: '$planifiesAVenir',
                  libelle: 'planifiés',
                  icone: Icons.event_outlined),
            ],
          ),
          enfants: [
            _filtres(),
            if (tous.isEmpty)
              const EtatVideModule(
                icone: Icons.alt_route,
                titre: 'Aucun trajet pour le moment',
                message: 'Ajoutez le premier trajet proposé.',
              )
            else if (visibles.isEmpty)
              const EtatVideModule(
                icone: Icons.search_off,
                titre: 'Aucun résultat',
                message: 'Modifiez la recherche ou le filtre.',
              ),
            for (final t in visibles) _carte(t),
          ],
        );
      },
    );
  }

  Widget _filtres() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            decoration: decorationUi('Rechercher une ville ou une adresse',
                icone: Icons.search),
          ),
          const SizedBox(height: 12),
          ChampChoix<StatutTrajet?>(
            label: 'Statut',
            icone: Icons.flag_outlined,
            valeur: _statut,
            items: [
              const DropdownMenuItem<StatutTrajet?>(
                  value: null, child: Text('Tous les statuts')),
              for (final s in StatutTrajet.values)
                DropdownMenuItem<StatutTrajet?>(value: s, child: Text(s.libelle)),
            ],
            onChange: (v) => setState(() => _statut = v),
          ),
          const SizedBox(height: 12),
          ChampChoix<_Tri>(
            label: 'Trier par',
            icone: Icons.sort,
            valeur: _tri,
            items: [
              for (final t in _Tri.values)
                DropdownMenuItem<_Tri>(value: t, child: Text(_libelleTri(t))),
            ],
            onChange: (v) => setState(() => _tri = v ?? _tri),
          ),
        ],
      );

  Widget _carte(TrajetTransport t) => CarteTransport(
        onTap: t.statut == StatutTrajet.planifie ? () => ajouter(t) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: LigneTrajet(depart: t.villeDepart, arrivee: t.destination)),
                const SizedBox(width: 8),
                Pastille(libelle: t.statut.libelle, valeur: t.statut.valeur),
              ],
            ),
            const SizedBox(height: 8),
            LigneInfo(
              icone: Icons.event_outlined,
              texte: '${dateCourte(t.dateDepart)} · '
                  '${TransportFormat.heure(t.dateDepart)} → '
                  '${TransportFormat.heure(t.dateArriveeEstimee)}',
            ),
            const SizedBox(height: 4),
            LigneInfo(
              icone: Icons.airline_seat_recline_normal,
              texte: '${t.placesReservees}/${t.placesTotales} réservées · '
                  '${t.placesLibres} libre(s) · '
                  '${TransportFormat.prix(t.prixParPersonne)} par personne',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_vert, color: AppColors.grey),
                itemBuilder: (_) => _menu(t),
                onSelected: (a) => _agir(a, t),
              ),
            ),
          ],
        ),
      );
}

// ----------------------------------------------------------------------
// Section « Réservations »
// ----------------------------------------------------------------------

/// Contenu de la section « Réservations » : passagers confirmés et demandes annulées.
class _Reservations {
  final List<ReservationTransport> confirmees;
  final List<MiseEnRelation> annulees;

  const _Reservations(this.confirmees, this.annulees);
}

class _ListeReservations extends StatefulWidget {
  final int utilisateurId;
  final Widget selecteur;

  const _ListeReservations({required this.utilisateurId, required this.selecteur});

  @override
  State<_ListeReservations> createState() => _ListeReservationsState();
}

class _ListeReservationsState extends State<_ListeReservations> {
  final _repo = TransportRepository();
  late Future<_Reservations> _liste = _charger();
  ActualisationAuto? _actu;

  @override
  void initState() {
    super.initState();
    _actu = ActualisationAuto(rafraichir: _recharger)..demarrer();
  }

  @override
  void dispose() {
    _actu?.arreter();
    super.dispose();
  }

  /// Passagers confirmés et demandes refusées (annulées), chargés ensemble.
  Future<_Reservations> _charger() async {
    final confirmees = await _repo.reservationsDuTransporteur(widget.utilisateurId);
    final annulees = await _repo.relationsDuTransporteur(widget.utilisateurId,
        statut: StatutRelation.refusee);
    return _Reservations(confirmees, annulees);
  }

  void _recharger() => setState(() => _liste = _charger());

  Future<void> _prendreEnCharge(ReservationTransport r) async {
    final id = r.id;
    if (id == null) return;
    final erreur = await _repo.confirmerPriseEnCharge(id, widget.utilisateurId);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Prise en charge confirmée',
        erreur: erreur != null);
    _recharger();
  }

  Future<void> _annuler(ReservationTransport r) async {
    final id = r.id;
    if (id == null) return;
    final motif = await demanderMotif(
      context,
      titre: 'Annuler la réservation ?',
      action: 'Annuler la réservation',
      message: 'Le voyageur sera informé du motif. Le motif est obligatoire.',
    );
    if (motif == null || !mounted) return;
    final erreur =
        await _repo.annulerReservationParTransporteur(id, widget.utilisateurId, motif: motif);
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Réservation annulée', erreur: erreur != null);
    _recharger();
  }

  Future<void> _historique(ReservationTransport r) async {
    final id = r.id;
    if (id == null) return;
    final evenements = await _repo.historique(id);
    if (!mounted) return;
    await afficherHistorique(context, evenements);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Reservations>(
      future: _liste,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final erreur = snap.hasError;
        if (erreur) debugPrint('Réservations transporteur : ${snap.error}');
        final contenu = snap.data ?? const _Reservations([], []);
        final items = erreur ? const <ReservationTransport>[] : contenu.confirmees;
        final annulees = erreur ? const <MiseEnRelation>[] : contenu.annulees;
        final actives = items.where((r) => r.active).toList();
        final placesReservees =
            actives.fold<int>(0, (somme, r) => somme + r.nombrePlaces);
        return CorpsListeTransport(
          onRefresh: () async => _recharger(),
          selecteur: widget.selecteur,
          entete: EnTeteModule(
            titre: 'Réservations confirmées',
            sousTitre: 'Passagers, places réservées et prises en charge.',
            icone: Icons.event_available_outlined,
            indicateurs: [
              IndicateurEnTete(
                  valeur: '${actives.length}',
                  libelle: 'actives',
                  icone: Icons.event_available_outlined),
              IndicateurEnTete(
                  valeur: '$placesReservees',
                  libelle: 'places réservées',
                  icone: Icons.airline_seat_recline_normal),
            ],
          ),
          enfants: [
            if (erreur)
              EtatVideModule(
                icone: Icons.error_outline,
                titre: 'Chargement impossible',
                message: 'Vérifiez la connexion puis réessayez.',
                libelleAction: 'Réessayer',
                onAction: _recharger,
              ),
            if (!erreur && items.isEmpty && annulees.isEmpty)
              const EtatVideModule(
                icone: Icons.event_available_outlined,
                titre: 'Aucune réservation',
                message: 'Les réservations apparaissent ici après acceptation d\'une demande.',
              ),
            for (final r in items) _carte(r),
            if (annulees.isNotEmpty) ...[
              const EnteteSection(titre: 'Demandes annulées'),
              for (final m in annulees) _carteAnnulee(m),
            ],
          ],
        );
      },
    );
  }

  Widget _carteAnnulee(MiseEnRelation m) => CarteTransport(
        accent: AppColors.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: LigneTrajet(depart: m.depart, arrivee: m.arrivee)),
                const SizedBox(width: 8),
                const Pastille(libelle: 'Annulée', valeur: 'annulee'),
              ],
            ),
            const SizedBox(height: 4),
            Text('Réf. ${m.reference}',
                style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            LigneInfo(
              icone: Icons.event_outlined,
              texte: '${dateCourte(m.dateVoyage)} à ${TransportFormat.heure(m.dateVoyage)}',
            ),
            const SizedBox(height: 4),
            LigneInfo(
              icone: Icons.group_outlined,
              texte: '${m.nombrePassagers} passager(s) · demande refusée',
            ),
          ],
        ),
      );

  Widget _carte(ReservationTransport r) {
    final active = r.active;
    return CarteTransport(
      accent: active ? null : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: LigneTrajet(depart: r.villeDepart, arrivee: r.destination)),
              const SizedBox(width: 8),
              Pastille(libelle: r.statut.libelle, valeur: r.statut.valeur),
            ],
          ),
          const SizedBox(height: 8),
          LigneInfo(
            icone: Icons.event_outlined,
            texte: '${dateCourte(r.dateDepart)} à ${TransportFormat.heure(r.dateDepart)}',
          ),
          const SizedBox(height: 4),
          LigneInfo(
            icone: Icons.person_outline,
            texte: '${r.nomVoyageur} · ${r.nombrePlaces} place(s) réservée(s)',
          ),
          const SizedBox(height: 4),
          LigneInfo(icone: Icons.phone_outlined, texte: r.telephoneVoyageur),
          if (!active) ...[
            const SizedBox(height: 6),
            Text('Motif : ${r.motifAnnulation}',
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (r.statut == StatutReservation.confirmee)
                FilledButton.tonal(
                  onPressed: () => _prendreEnCharge(r),
                  child: const Text('Prise en charge'),
                ),
              if (active)
                OutlinedButton(
                  onPressed: () => _annuler(r),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Annuler'),
                ),
              TextButton.icon(
                onPressed: () => _historique(r),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Historique'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
