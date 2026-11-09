import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/transporteur.dart';
import '../transport_format.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';

/// Création ou modification du profil transporteur. La photo ou le logo est facultatif :
/// l'image est réduite à l'import puis stockée en base (base64).
class TransporteurFormScreen extends StatefulWidget {
  final int utilisateurId;
  final Transporteur? profil;

  const TransporteurFormScreen({super.key, required this.utilisateurId, this.profil});

  @override
  State<TransporteurFormScreen> createState() => _TransporteurFormScreenState();
}

class _TransporteurFormScreenState extends State<TransporteurFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = TransportRepository();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _ville = TextEditingController();
  final _zone = TextEditingController();
  final _capacite = TextEditingController();
  final _description = TextEditingController();
  final _tarifs = TextEditingController();
  String _type = Transporteur.types.first;
  bool _disponible = true;
  String _photo = '';
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profil;
    _nom.text = p?.nom ?? '';
    _telephone.text = p?.telephone ?? '';
    _email.text = p?.email ?? '';
    _ville.text = p?.ville ?? '';
    _zone.text = p?.zoneCouverture ?? '';
    _capacite.text = '${p?.capacite ?? 4}';
    _description.text = p?.description ?? '';
    _tarifs.text = p?.tarifs ?? '';
    _type = p?.typeTransport ?? Transporteur.types.first;
    _disponible = p?.disponible ?? true;
    _photo = p?.photo ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _nom,
      _telephone,
      _email,
      _ville,
      _zone,
      _capacite,
      _description,
      _tarifs,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (image == null) return;
    final octets = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = base64Encode(octets));
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _occupe = true);
    final p = widget.profil;
    final profil = Transporteur(
      id: p?.id,
      utilisateurId: widget.utilisateurId,
      nom: _nom.text,
      telephone: _telephone.text,
      email: _email.text,
      photo: _photo,
      ville: _ville.text,
      zoneCouverture: _zone.text,
      typeTransport: _type,
      capacite: TransportFormat.parserEntier(_capacite.text) ?? 1,
      description: _description.text,
      tarifs: _tarifs.text,
      disponible: _disponible,
      actif: p?.actif ?? true,
      noteMoyenne: p?.noteMoyenne ?? 0,
      creeLe: p?.creeLe ?? DateTime.now(),
    );
    final String? erreur;
    if (p == null) {
      erreur = await _repo.creerProfil(profil);
    } else {
      erreur = await _repo.modifierProfil(profil) ? null : 'Modification impossible';
    }
    if (!mounted) return;
    setState(() => _occupe = false);
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    afficherMessage(context, p == null ? 'Profil créé' : 'Profil mis à jour');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final photo = imageProfil(_photo);
    return EcranModule(
      titre: widget.profil == null ? 'Créer mon profil' : 'Modifier mon profil',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.tealLight,
                backgroundImage: photo,
                child: photo == null
                    ? const Icon(Icons.local_shipping_outlined,
                        size: 40, color: AppColors.teal)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _choisirPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(_photo.isEmpty ? 'Ajouter une photo ou un logo' : 'Changer'),
                ),
                if (_photo.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _photo = ''),
                    child: const Text('Retirer'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ChampTexte(
              controller: _nom,
              label: 'Nom ou raison sociale',
              icone: Icons.badge_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) => Validators.requis(v, champ: 'Le nom'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _telephone,
              label: 'Téléphone',
              icone: Icons.phone_outlined,
              clavier: TextInputType.phone,
              validateur: Validators.telephone,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _email,
              label: 'E-mail',
              icone: Icons.mail_outline,
              clavier: TextInputType.emailAddress,
              validateur: Validators.email,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _ville,
              label: 'Ville',
              icone: Icons.location_city_outlined,
              capitalisation: TextCapitalization.words,
              validateur: (v) => TransportFormat.validerVille(v, champ: 'La ville'),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _zone,
              label: 'Zone de couverture (ex : Cap Bon, Sahel)',
              icone: Icons.map_outlined,
            ),
            const SizedBox(height: 14),
            ChampChoix<String>(
              label: 'Type de transport',
              icone: Icons.directions_bus_outlined,
              valeur: _type,
              items: [
                for (final t in Transporteur.types)
                  DropdownMenuItem<String>(
                      value: t, child: Text(Transporteur.libelleType(t))),
              ],
              onChange: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _capacite,
              label: 'Capacité (places)',
              icone: Icons.airline_seat_recline_normal,
              clavier: TextInputType.number,
              validateur: (v) =>
                  TransportFormat.validerEntier(v, champ: 'La capacité', max: 99),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _tarifs,
              label: 'Tarifs (ex : 15 DT par personne)',
              icone: Icons.payments_outlined,
              lignes: 2,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _description,
              label: 'Description',
              icone: Icons.notes_outlined,
              lignes: 3,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Disponible pour de nouvelles demandes'),
              activeColor: AppColors.teal,
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
            ),
            const SizedBox(height: 20),
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
