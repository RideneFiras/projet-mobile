import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../actualite_api.dart';
import '../actualite_fil.dart';
import '../admin_repository.dart';
import '../sondage_repository.dart';

/// Publication (actualite == null) ou modification d'une actualité.
/// Tout utilisateur connecté peut publier dans le fil commun ; chacun ne
/// modifie que ses propres publications (contrôlé par l'écran appelant).
/// Renvoie true à la fermeture si quelque chose a été enregistré.
class ActualiteFormScreen extends StatefulWidget {
  final Actualite? actualite;

  const ActualiteFormScreen({super.key, this.actualite});

  @override
  State<ActualiteFormScreen> createState() => _ActualiteFormScreenState();
}

class _ActualiteFormScreenState extends State<ActualiteFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _repo = AdminRepository();
  late final TextEditingController _titre;
  late final TextEditingController _contenu;
  late final TextEditingController _theme;
  late final TextEditingController _lieu;
  late final List<TextEditingController> _options;
  CategorieActualite _categorie = CategorieActualite.general;
  String? _photoBase64;
  bool _sondage = false;
  bool _annonce = false;
  DateTime? _dateEvenement;
  bool _enregistrement = false;
  bool _generation = false;

  bool get _modeEdition => widget.actualite != null;

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController(text: widget.actualite?.titre ?? '');
    _contenu = TextEditingController(text: widget.actualite?.contenu ?? '');
    _theme = TextEditingController();
    _lieu = TextEditingController(text: widget.actualite?.lieu ?? '');
    _options = List.generate(4, (_) => TextEditingController());
    _categorie = widget.actualite?.categorie ?? CategorieActualite.general;
    _photoBase64 = widget.actualite?.photo;
    _annonce = widget.actualite?.typePost == TypePost.annonce;
    _dateEvenement = widget.actualite?.dateEvenement;
  }

  /// Photo du post (galerie ou appareil photo), réduite puis encodée en base64.
  Future<void> _choisirPhoto() async {
    final fichier = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 75,
    );
    if (fichier == null || !mounted) return;
    final octets = await fichier.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBase64 = base64Encode(octets));
  }

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    _theme.dispose();
    _lieu.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  /// Options de sondage remplies (2 minimum requises).
  List<String> get _optionsRemplies =>
      _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

  /// Brouillon généré par le serveur IA (ou gabarit local si le serveur est
  /// absent) : il remplit les champs, l'administrateur le relit avant de publier.
  Future<void> _genererBrouillon() async {
    final theme = _theme.text.trim();
    if (theme.length < 5) {
      afficherMessage(context, 'Indiquez un thème d’au moins 5 caractères', erreur: true);
      return;
    }
    setState(() => _generation = true);
    final b = await ActualiteApi.brouillon(
      theme: theme,
      categorie: _categorie,
    );
    if (!mounted) return;
    setState(() {
      _titre.text = b.titre;
      _contenu.text = b.contenu;
      _generation = false;
    });
    afficherMessage(
      context,
      b.source == SourceBrouillon.serveur
          ? 'Brouillon généré par le serveur : relisez-le avant de publier'
          : 'Serveur indisponible : brouillon local, à compléter avant de publier',
    );
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final erreur = FilActualites.valider(_titre.text, _contenu.text, sondage: _sondage);
    if (erreur != null) {
      afficherMessage(context, erreur, erreur: true);
      return;
    }
    if (_sondage && !_modeEdition && _optionsRemplies.length < 2) {
      afficherMessage(context, 'Un sondage a besoin d’au moins 2 choix', erreur: true);
      return;
    }
    final auteurId = await SessionService.instance.utilisateurId();
    if (!mounted || auteurId == null) return;
    setState(() => _enregistrement = true);
    try {
    if (_modeEdition) {
      await _repo.modifierActualite(
        widget.actualite!.id!,
        titre: _titre.text,
        contenu: _contenu.text,
        categorie: _categorie,
        photoBase64: _photoBase64,
      );
    } else {
      final nouvelId = await _repo.publier(
        titre: _titre.text,
        contenu: _contenu.text,
        auteurId: auteurId,
        categorie: _categorie,
        photoBase64: _photoBase64,
        typePost: _annonce ? TypePost.annonce : TypePost.standard,
        dateEvenement: _annonce ? _dateEvenement?.toIso8601String() : null,
        lieu: _annonce && _lieu.text.trim().isNotEmpty ? _lieu.text.trim() : null,
      );
      if (_sondage && _optionsRemplies.isNotEmpty) {
        await SondageRepository().creerOptions(nouvelId, _optionsRemplies);
      }
    }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      afficherMessage(context, 'Publication impossible : $e', erreur: true);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier l\'actualité' : 'Publier une actualité',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ChampTexte(
              controller: _titre,
              label: _sondage ? 'Question du sondage' : 'Titre',
              icone: _sondage ? Icons.help_outline : Icons.title,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Le titre est obligatoire' : null,
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _contenu,
              label: _sondage ? 'Texte (facultatif)' : 'Contenu',
              icone: Icons.article_outlined,
              lignes: 7,
              capitalisation: TextCapitalization.sentences,
              validateur: (v) => _sondage
                  ? null
                  : ((v == null || v.trim().isEmpty) ? 'Le contenu est obligatoire' : null),
            ),
            const SizedBox(height: 14),
            if (_photoBase64 != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(_photoBase64!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: IconButton(
                        tooltip: 'Retirer la photo',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 18, color: AppColors.white),
                        onPressed: () => setState(() => _photoBase64 = null),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photoBase64 != null) const SizedBox(height: 10),
            BoutonSecondaire(
              libelle: 'Photo',
              icone: Icons.add_a_photo_outlined,
              onPressed: _choisirPhoto,
            ),
            if (!_modeEdition) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Sondage',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Switch(value: _sondage, onChanged: (v) => setState(() => _sondage = v)),
                ],
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text('Annonce',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Switch(value: _annonce, onChanged: (v) => setState(() => _annonce = v)),
                ],
              ),
              if (_annonce) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateEvenement ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _dateEvenement = d);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: AppColors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dateEvenement == null
                                ? 'Choisir une date'
                                : 'Le ${_dateEvenement!.day}/${_dateEvenement!.month}/${_dateEvenement!.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _dateEvenement == null
                                  ? const Color(0xFF8A97A5)
                                  : AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ChampTexte(
                  controller: _lieu,
                  label: 'Lieu (facultatif)',
                  icone: Icons.place_outlined,
                ),
              ],
              if (_sondage)
                for (var i = 0; i < _options.length; i++) ...[
                  const SizedBox(height: 10),
                  ChampTexte(
                    controller: _options[i],
                    label: 'Choix ${i + 1}${i < 2 ? ' (requis)' : ''}',
                    icone: Icons.radio_button_checked_outlined,
                  ),
                ],
            ],
            const SizedBox(height: 14),
            ChampChoix<CategorieActualite>(
              label: 'Catégorie',
              icone: Icons.category_outlined,
              valeur: _categorie,
              items: [
                for (final c in CategorieActualite.values)
                  DropdownMenuItem(value: c, child: Text(c.libelle)),
              ],
              onChange: (v) => setState(() => _categorie = v ?? CategorieActualite.general),
            ),
            const SizedBox(height: 14),
            ChampTexte(
              controller: _theme,
              label: 'Brouillon IA',
              icone: Icons.lightbulb_outline,
              capitalisation: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            BoutonSecondaire(
              libelle: _generation ? '…' : 'Générer',
              icone: Icons.auto_awesome_outlined,
              onPressed: _generation || _enregistrement ? null : _genererBrouillon,
            ),
            const SizedBox(height: 28),
            BoutonPrincipal(
              libelle: _modeEdition ? 'Enregistrer' : 'Publier',
              icone: Icons.campaign_outlined,
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
