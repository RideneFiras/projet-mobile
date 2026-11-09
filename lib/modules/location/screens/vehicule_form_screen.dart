import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../location_repository.dart';
import '../models/vehicule.dart';

/// Ajout ou modification d'un véhicule de location. Renvoie true si enregistré.
class VehiculeFormScreen extends StatefulWidget {
  final Vehicule? vehicule;

  const VehiculeFormScreen({super.key, this.vehicule});

  @override
  State<VehiculeFormScreen> createState() => _VehiculeFormScreenState();
}

class _VehiculeFormScreenState extends State<VehiculeFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = LocationRepository();
  late final TextEditingController _marque;
  late final TextEditingController _modele;
  late final TextEditingController _prix;
  late bool _disponible;
  bool _enregistrement = false;

  bool get _modeEdition => widget.vehicule != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicule;
    _marque = TextEditingController(text: v?.marque ?? '');
    _modele = TextEditingController(text: v?.modele ?? '');
    _prix = TextEditingController(
        text: v == null ? '' : v.prixParJour.toStringAsFixed(2));
    _disponible = v?.disponible ?? true;
  }

  @override
  void dispose() {
    _marque.dispose();
    _modele.dispose();
    _prix.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    setState(() => _enregistrement = true);
    final vehicule = Vehicule(
      id: widget.vehicule?.id,
      marque: _marque.text,
      modele: _modele.text,
      prixParJour: Montants.depuisSaisie(_prix.text) ?? 0,
      disponible: _disponible,
    );
    if (_modeEdition) {
      await _repo.modifierVehicule(vehicule);
    } else {
      await _repo.creerVehicule(vehicule);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier le véhicule' : 'Nouveau véhicule',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ChampTexte(
              controller: _marque,
              label: 'Marque',
              icone: Icons.directions_car_outlined,
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
            ChampTexte(
              controller: _prix,
              label: 'Prix par jour (DT)',
              icone: Icons.payments_outlined,
              clavier: const TextInputType.numberWithOptions(decimal: true),
              validateur: (v) => Montants.valider(v),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                activeThumbColor: AppColors.teal,
                title: const Text('Disponible à la location',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Un véhicule indisponible ne peut plus être réservé.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey)),
                value: _disponible,
                onChanged: (v) => setState(() => _disponible = v),
              ),
            ),
            const SizedBox(height: 28),
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
}
