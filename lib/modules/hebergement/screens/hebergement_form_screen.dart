import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_repository.dart';
import '../models/hebergement.dart';

/// Ajout ou modification d'un établissement d'hébergement. Renvoie true si enregistré.
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
  late final TextEditingController _prix;
  String? _type;
  bool _tentative = false;
  bool _enregistrement = false;

  bool get _modeEdition => widget.hebergement != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hebergement;
    _nom = TextEditingController(text: h?.nom ?? '');
    _adresse = TextEditingController(text: h?.adresse ?? '');
    _prix = TextEditingController(
        text: h == null ? '' : h.prixParNuit.toStringAsFixed(2));
    _type = h?.type;
  }

  @override
  void dispose() {
    _nom.dispose();
    _adresse.dispose();
    _prix.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _tentative = true);
    final formOk = _cle.currentState?.validate() ?? false;
    if (!formOk || _type == null) return;
    setState(() => _enregistrement = true);
    final h = Hebergement(
      id: widget.hebergement?.id,
      nom: _nom.text,
      type: _type!,
      adresse: _adresse.text,
      prixParNuit: Montants.depuisSaisie(_prix.text) ?? 0,
    );
    if (_modeEdition) {
      await _repo.modifierHebergement(h);
    } else {
      await _repo.creerHebergement(h);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
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
            ChampTexte(
              controller: _nom,
              label: 'Nom de l\'établissement',
              icone: Icons.bed_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) => Validators.requis(v, champ: 'Le nom'),
            ),
            const SizedBox(height: 14),
            ChampChoix<String>(
              label: 'Type',
              icone: Icons.category_outlined,
              valeur: _type,
              erreur: _tentative && _type == null ? 'Choisissez un type' : null,
              items: [
                for (final t in Hebergement.types)
                  DropdownMenuItem<String>(value: t, child: Text(t)),
              ],
              onChange: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _adresse,
              label: 'Adresse',
              icone: Icons.place_outlined,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) => Validators.requis(v, champ: 'L\'adresse'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _prix,
              label: 'Prix par nuit (DT)',
              icone: Icons.payments_outlined,
              clavier: const TextInputType.numberWithOptions(decimal: true),
              validateur: (v) => Montants.valider(v),
            ),
            const SizedBox(height: 28),
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
              'Les séjours déjà réservés dans un établissement sont conservés si vous modifiez ses informations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
