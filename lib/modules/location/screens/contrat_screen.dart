import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as chemin;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/zone_signature.dart';
import '../contrat_location.dart';
import '../location_repository.dart';
import '../models/location_vehicule.dart';
import '../models/vehicule.dart';

/// Contrat de location : résumé, conditions, signature électronique du locataire
/// (tracé au doigt) et génération du PDF enregistré sur l'appareil.
/// Renvoie true si le contrat a été signé.
class ContratScreen extends StatefulWidget {
  final int locationId;

  const ContratScreen({super.key, required this.locationId});

  @override
  State<ContratScreen> createState() => _ContratScreenState();
}

typedef _Donnees = (LocationVehicule?, Vehicule?, List<TraitSignature>);

class _ContratScreenState extends State<ContratScreen> {
  final _repo = LocationRepository();
  late Future<_Donnees> _futur;
  List<TraitSignature> _traits = const [];
  bool _accepte = false;
  bool _travail = false;
  bool _signe = false;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  Future<_Donnees> _charger() async {
    final l = await _repo.location(widget.locationId);
    final v = l == null ? null : await _repo.vehicule(l.vehiculeId);
    return (l, v, await _repo.signatureDe(widget.locationId));
  }

  /// Traits normalisés (0..1) pour être reproduits dans le cadre du PDF.
  void _surSignature(List<List<Offset>> traits, Size taille) {
    if (taille.width <= 0 || taille.height <= 0) return;
    setState(() => _traits = [
          for (final t in traits)
            [for (final p in t) (p.dx / taille.width, p.dy / taille.height)],
        ]);
  }

  Future<void> _signer() async {
    setState(() => _travail = true);
    final ok = await _repo.signerContrat(widget.locationId, _traits);
    if (!mounted) return;
    setState(() {
      _travail = false;
      _signe = _signe || ok;
      _futur = _charger();
    });
    afficherMessage(context, ok ? 'Contrat signé' : 'Signature impossible', erreur: !ok);
  }

  Future<void> _genererPdf(LocationVehicule l, Vehicule v, List<TraitSignature> signature) async {
    if (kIsWeb) {
      afficherMessage(context, 'Le PDF s\'enregistre depuis l\'application mobile.',
          erreur: true);
      return;
    }
    setState(() => _travail = true);
    try {
      final octets = ContratLocation.genererPdf(
        location: l,
        vehicule: v,
        nomClient: l.nomClient ?? 'Client',
        emailClient: l.emailClient,
        signature: signature,
        signeLe: l.contratSigneLe,
      );
      // Android : dossier de l'application visible depuis l'explorateur de fichiers
      // (Android/data/<application>/files) ; ailleurs : documents de l'application.
      final dossier = (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
          await getApplicationDocumentsDirectory();
      final fichier = File(chemin.join(dossier.path, 'contrats', 'contrat_LV-${l.id}.pdf'));
      await fichier.parent.create(recursive: true);
      await fichier.writeAsBytes(octets, flush: true);
      if (!mounted) return;
      setState(() => _travail = false);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Contrat enregistré'),
          content: SelectableText(fichier.path),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: fichier.path)),
              child: const Text('Copier le chemin'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } on FileSystemException catch (e) {
      if (!mounted) return;
      setState(() => _travail = false);
      afficherMessage(context, 'Enregistrement impossible : ${e.message}', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (aFerme, _) {
        if (!aFerme) Navigator.pop(context, _signe);
      },
      child: EcranModule(
        titre: 'Contrat de location',
        corps: FutureBuilder<_Donnees>(
          future: _futur,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (l, v, signature) = snap.data!;
            if (l == null || v == null) {
              return const EtatVideModule(
                icone: Icons.search_off,
                titre: 'Location introuvable',
                message: 'Elle a peut-être été supprimée.',
              );
            }
            return _contenu(l, v, signature);
          },
        ),
      ),
    );
  }

  Widget _contenu(LocationVehicule l, Vehicule v, List<TraitSignature> signature) {
    final signeLe = l.contratSigneLe;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CarteModule(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contrat n° LV-${l.id}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _ligne('Locataire', l.nomClient ?? '—'),
              if (l.numeroPermis != null) _ligne('Permis', l.numeroPermis!),
              _ligne('Véhicule', '${v.type.libelle} ${v.nom}'
                  '${v.immatriculation == null ? '' : ' (${v.immatriculation})'}'),
              _ligne('Période', '${periode(l.dateDebut, l.dateFin)} · ${l.jours} j'),
              _ligne('Prise en charge', l.lieuPrise ?? 'À l\'agence'),
              if (l.options.isNotEmpty)
                _ligne('Options', l.options.map((o) => o.libelle).join(', ')),
              _ligne('Prix total', Montants.affiche(l.prixTotal)),
              _ligne('Caution', Montants.affiche(l.caution)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const EnteteSection(titre: 'Conditions'),
        const SizedBox(height: 8),
        Text(
          '• Retour à la date prévue, au lieu convenu, dans l\'état du départ.\n'
          '• Chaque jour de retard : ${Montants.affiche(v.prixParJour * LocationVehicule.coefficientRetard)}.\n'
          '• Amendes et péages à la charge du locataire.\n'
          '• Caution retenue en cas de dommage constaté au retour.',
          style: const TextStyle(color: AppColors.navy, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (signeLe != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Signé électroniquement le ${dateCourte(signeLe)}',
                      style: const TextStyle(
                          color: AppColors.teal, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ] else if (l.annulee) ...[
          const Text('Location annulée : le contrat ne peut plus être signé.',
              style: TextStyle(color: AppColors.danger)),
        ] else ...[
          const EnteteSection(titre: 'Signature du locataire'),
          const SizedBox(height: 8),
          ZoneSignature(onChange: _surSignature),
          CheckboxListTile(
            value: _accepte,
            onChanged: (v) => setState(() => _accepte = v ?? false),
            title: const Text('J\'ai lu et j\'accepte les conditions du contrat'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.teal,
          ),
          BoutonPrincipal(
            libelle: 'Signer le contrat',
            icone: Icons.draw_outlined,
            onPressed: (_accepte && _traits.isNotEmpty && !_travail) ? _signer : null,
          ),
        ],
        const SizedBox(height: 12),
        BoutonSecondaire(
          libelle: _travail ? 'Patientez…' : 'Générer le contrat PDF',
          onPressed: _travail ? null : () => _genererPdf(l, v, signature),
        ),
      ],
    );
  }

  Widget _ligne(String libelle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(libelle,
                  style: const TextStyle(color: AppColors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(valeur,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );
}
