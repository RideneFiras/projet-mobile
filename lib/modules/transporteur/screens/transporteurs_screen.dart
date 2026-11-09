import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../user/role.dart';
import '../../user/utilisateur.dart';
import '../models/transporteur.dart';
import '../transport_repository.dart';
import '../transport_widgets.dart';
import 'transporteur_form_screen.dart';

/// Profil du transporteur connecté : lecture, modification et désactivation.
/// Le profil n'est jamais supprimé : désactivé, il disparaît seulement des recherches.
class TransporteursScreen extends StatefulWidget {
  const TransporteursScreen({super.key});

  @override
  State<TransporteursScreen> createState() => _TransporteursScreenState();
}

class _TransporteursScreenState extends State<TransporteursScreen> {
  final _repo = TransportRepository();
  bool _charge = false;
  Utilisateur? _utilisateur;
  Transporteur? _profil;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final u = await utilisateurAutorise(role: Role.transporter);
    final id = u?.id;
    final profil = id == null ? null : await _repo.profilDe(id);
    if (!mounted) return;
    setState(() {
      _utilisateur = u;
      _profil = profil;
      _charge = true;
    });
  }

  Future<void> _ouvrirFormulaire([Transporteur? profil]) async {
    final id = _utilisateur?.id;
    if (id == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransporteurFormScreen(utilisateurId: id, profil: profil),
      ),
    );
    if (ok == true) _charger();
  }

  Future<void> _changerActivite(Transporteur profil) async {
    final id = _utilisateur?.id;
    if (id == null) return;
    if (profil.actif) {
      final ok = await confirmer(
        context,
        titre: 'Désactiver mon profil ?',
        message: "Votre profil n'apparaîtra plus dans les recherches des voyageurs. "
            'Vos trajets et réservations déjà confirmés restent gérés.',
        action: 'Désactiver',
      );
      if (!ok || !mounted) return;
    }
    await _repo.changerActivite(id, actif: !profil.actif);
    if (!mounted) return;
    afficherMessage(context, profil.actif ? 'Profil désactivé' : 'Profil réactivé');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    const titre = 'Mon profil';
    if (!_charge) {
      return const EcranModule(
        titre: titre,
        corps: Center(child: CircularProgressIndicator()),
      );
    }
    if (_utilisateur == null) {
      return const EcranModule(
        titre: titre,
        corps: EtatVideModule(
          icone: Icons.local_shipping_outlined,
          titre: 'Accès réservé',
          message: 'Cet écran est réservé aux comptes transporteur.',
        ),
      );
    }
    final profil = _profil;
    if (profil == null) {
      return EcranModule(
        titre: titre,
        corps: EtatVideModule(
          icone: Icons.local_shipping_outlined,
          titre: 'Aucun profil pour le moment',
          message: 'Créez votre profil pour apparaître dans les recherches des voyageurs.',
          libelleAction: 'Créer mon profil',
          onAction: () => _ouvrirFormulaire(),
        ),
      );
    }
    return EcranModule(
      titre: titre,
      actions: [
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _ouvrirFormulaire(profil),
        ),
      ],
      corps: CorpsListeTransport(
        onRefresh: _charger,
        entete: EnTeteModule(
          titre: profil.nom,
          sousTitre: '${Transporteur.libelleType(profil.typeTransport)} · ${profil.ville}',
          icone: Icons.local_shipping_outlined,
          indicateurs: [
            IndicateurEnTete(
                valeur: '${profil.nbTrajets}', libelle: 'trajets', icone: Icons.alt_route),
            IndicateurEnTete(
              valeur: profil.noteMoyenne > 0 ? profil.noteMoyenne.toStringAsFixed(1) : '—',
              libelle: 'note sur 5',
              icone: Icons.star_outline,
            ),
            IndicateurEnTete(
              valeur: '${profil.capacite}',
              libelle: 'places',
              icone: Icons.airline_seat_recline_normal,
            ),
          ],
        ),
        enfants: [
          CarteTransport(child: _carteIdentite(profil)),
          CarteTransport(child: _carteActions(profil)),
        ],
      ),
    );
  }

  Widget _carteIdentite(Transporteur profil) {
    final photo = imageProfil(profil.photo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.tealLight,
              backgroundImage: photo,
              child: photo == null
                  ? const Icon(Icons.local_shipping_outlined, color: AppColors.teal)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(profil.nom,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pastille(
              libelle: profil.actif ? 'Actif' : 'Désactivé',
              valeur: profil.actif ? 'actif' : 'annule',
            ),
            Pastille(
              libelle: profil.disponible ? 'Disponible' : 'Indisponible',
              valeur: profil.disponible ? 'disponible' : 'indisponible',
            ),
          ],
        ),
        const SizedBox(height: 12),
        LigneInfo(icone: Icons.phone_outlined, texte: profil.telephone),
        const SizedBox(height: 6),
        LigneInfo(icone: Icons.mail_outline, texte: profil.email),
        const SizedBox(height: 6),
        LigneInfo(
          icone: Icons.place_outlined,
          texte: profil.zoneCouverture.isEmpty
              ? profil.ville
              : '${profil.ville} · ${profil.zoneCouverture}',
        ),
        if (profil.tarifs.isNotEmpty) ...[
          const SizedBox(height: 6),
          LigneInfo(icone: Icons.payments_outlined, texte: profil.tarifs),
        ],
        if (profil.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          LigneInfo(icone: Icons.notes_outlined, texte: profil.description),
        ],
      ],
    );
  }

  Widget _carteActions(Transporteur profil) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoutonSecondaire(
            libelle: 'Modifier mon profil',
            icone: Icons.edit_outlined,
            onPressed: () => _ouvrirFormulaire(profil),
          ),
          const SizedBox(height: 10),
          BoutonSecondaire(
            libelle: profil.actif ? 'Désactiver mon profil' : 'Réactiver mon profil',
            icone: profil.actif
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onPressed: () => _changerActivite(profil),
          ),
        ],
      );
}
