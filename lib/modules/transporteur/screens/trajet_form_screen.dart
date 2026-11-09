import 'package:flutter/material.dart';

import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../models/reservation_transport.dart';
import '../models/transporteur.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Création ou modification d'un trajet proposé (table reservation_transport).
/// Règle du cahier des charges : départ différent de l'arrivée (contrôlé ici
/// et par la base de données).
class TrajetFormScreen extends StatefulWidget {
  final ReservationTransport? trajet;

  const TrajetFormScreen({super.key, this.trajet});

  @override
  State<TrajetFormScreen> createState() => _TrajetFormScreenState();
}

class _TrajetFormScreenState extends State<TrajetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = TransportRepository();
  late final _depart = TextEditingController(text: widget.trajet?.depart);
  late final _arrivee = TextEditingController(text: widget.trajet?.arrivee);
  late final _prix = TextEditingController(
      text: widget.trajet?.prix.toStringAsFixed(2));
  late final Future<List<Transporteur>> _fiches = _repo.transporteurs();

  late DateTime? _date = widget.trajet?.dateDepart;
  late StatutTrajet _statut = widget.trajet?.statut ?? StatutTrajet.enAttente;
  int? _transporteurId;
  String? _erreurDate;
  bool _chargement = false;

  bool get _modification => widget.trajet != null;

  @override
  void initState() {
    super.initState();
    _transporteurId = widget.trajet?.transporteurId;
  }

  @override
  void dispose() {
    for (final c in [_depart, _arrivee, _prix]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    final dateChangee = _date != widget.trajet?.dateDepart;
    setState(() => _erreurDate =
        (!_modification || dateChangee) ? TransportFormat.validerDateFuture(_date) : null);
    if (!_formKey.currentState!.validate() || _erreurDate != null) return;

    setState(() => _chargement = true);
    final trajet = ReservationTransport(
      id: widget.trajet?.id,
      depart: _depart.text,
      arrivee: _arrivee.text,
      dateDepart: _date!,
      prix: TransportFormat.depuisCentimes(TransportFormat.parserMontant(_prix.text) ?? 0),
      statut: _statut,
      transporteurId: _transporteurId,
    );
    if (_modification) {
      await _repo.modifierTrajet(trajet);
    } else {
      await _repo.creerTrajet(trajet);
    }
    if (!mounted) return;
    montrerMessage(context, _modification ? 'Trajet mis à jour' : 'Trajet ajouté');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(
      titre: _modification ? 'Modifier le trajet' : 'Nouveau trajet',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TravelField(
                label: 'Départ',
                hint: 'Tunis',
                icone: Icons.trip_origin,
                controller: _depart,
                validator: (v) => TransportFormat.validerVille(v, champ: 'Le départ'),
              ),
              const SizedBox(height: 14),
              TravelField(
                label: 'Arrivée',
                hint: 'Sfax',
                icone: Icons.flag_outlined,
                controller: _arrivee,
                validator: (v) =>
                    TransportFormat.validerTrajet(_depart.text, v) ??
                    TransportFormat.validerVille(v, champ: "L'arrivée"),
              ),
              const SizedBox(height: 14),
              ChampDate(
                label: 'Date de départ',
                valeur: _date,
                erreur: _erreurDate,
                premiereDate: DateTime.now(),
                onChoisie: (d) => setState(() {
                  _date = d;
                  _erreurDate = null;
                }),
              ),
              const SizedBox(height: 14),
              TravelField(
                label: 'Prix (DT)',
                hint: '25.00',
                icone: Icons.payments_outlined,
                controller: _prix,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => TransportFormat.validerMontant(v),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Transporteur>>(
                future: _fiches,
                builder: (context, snap) {
                  final fiches = snap.data ?? const <Transporteur>[];
                  return DropdownButtonFormField<int?>(
                    initialValue: _transporteurId,
                    decoration: const InputDecoration(
                      labelText: 'Transporteur',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Non précisé')),
                      for (final t in fiches)
                        DropdownMenuItem<int?>(
                            value: t.id, child: Text('${t.nom} (${t.type})')),
                    ],
                    onChanged: (v) => setState(() => _transporteurId = v),
                  );
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<StatutTrajet>(
                initialValue: _statut,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  for (final s in StatutTrajet.values)
                    DropdownMenuItem(value: s, child: Text(s.libelle)),
                ],
                onChanged: (v) => setState(() => _statut = v ?? _statut),
              ),
              const SizedBox(height: 28),
              TravelButton(
                texte: _modification ? 'Enregistrer' : 'Ajouter le trajet',
                chargement: _chargement,
                onPressed: _enregistrer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
