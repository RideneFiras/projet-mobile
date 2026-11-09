import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/travel_button.dart';
import '../../../core/widgets/travel_field.dart';
import '../models/transporteur.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Création ou modification d'une fiche transporteur (table transporteur).
class TransporteurFormScreen extends StatefulWidget {
  final Transporteur? transporteur;

  const TransporteurFormScreen({super.key, this.transporteur});

  @override
  State<TransporteurFormScreen> createState() => _TransporteurFormScreenState();
}

class _TransporteurFormScreenState extends State<TransporteurFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = TransportRepository();
  late final _nom = TextEditingController(text: widget.transporteur?.nom);
  late final _contact = TextEditingController(text: widget.transporteur?.contact);
  late String _type = widget.transporteur?.type ?? Transporteur.types.first;
  bool _chargement = false;

  bool get _modification => widget.transporteur != null;

  @override
  void dispose() {
    _nom.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);
    final fiche = Transporteur(
      id: widget.transporteur?.id,
      nom: _nom.text,
      type: _type,
      contact: _contact.text,
    );
    if (_modification) {
      await _repo.modifierTransporteur(fiche);
    } else {
      await _repo.creerTransporteur(fiche);
    }
    if (!mounted) return;
    montrerMessage(context,
        _modification ? 'Transporteur mis à jour' : 'Transporteur ajouté');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranTransport(
      titre: _modification ? 'Modifier le transporteur' : 'Nouveau transporteur',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TravelField(
                label: 'Nom',
                hint: 'Transports Sahel',
                icone: Icons.business_outlined,
                controller: _nom,
                validator: (v) => Validators.requis(v, champ: 'Le nom'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de transport',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  for (final t in Transporteur.types)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 14),
              TravelField(
                label: 'Contact',
                hint: '+216 20 123 456',
                icone: Icons.phone_outlined,
                controller: _contact,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.requis(v, champ: 'Le contact'),
              ),
              const SizedBox(height: 28),
              TravelButton(
                texte: _modification ? 'Enregistrer' : 'Ajouter',
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
