import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../forum_repository.dart';
import '../models/avis.dart';

/// Rédaction d'un avis (avis == null) ou modification du sien.
/// Un avis porte sur un seul service ; la note va de 1 à 5.
class AvisFormScreen extends StatefulWidget {
  final Avis? avis;

  const AvisFormScreen({super.key, this.avis});

  @override
  State<AvisFormScreen> createState() => _AvisFormScreenState();
}

class _AvisFormScreenState extends State<AvisFormScreen> {
  final _repo = ForumRepository();
  late final TextEditingController _commentaire;
  late CibleAvis _cible;
  int? _cibleId;
  int _note = 0;
  late Future<List<(int, String)>> _cibles;
  bool _tentative = false;
  bool _enregistrement = false;

  bool get _modeEdition => widget.avis != null;

  @override
  void initState() {
    super.initState();
    _commentaire = TextEditingController(text: widget.avis?.commentaire ?? '');
    _cible = widget.avis?.cible ?? CibleAvis.transport;
    _cibleId = widget.avis?.cibleId;
    _note = widget.avis?.note ?? 0;
    _cibles = _repo.cibles(_cible);
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  void _changerType(CibleAvis type) {
    setState(() {
      _cible = type;
      _cibleId = null;
      _cibles = _repo.cibles(type);
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _tentative = true);
    if (_cibleId == null || _note < 1) return;
    final userId = await SessionService.instance.utilisateurId();
    if (!mounted || userId == null) return;
    setState(() => _enregistrement = true);

    final avis = Avis(
      id: widget.avis?.id,
      cible: _cible,
      cibleId: _cibleId!,
      note: _note,
      commentaire: _commentaire.text,
      creeLe: widget.avis?.creeLe ?? DateTime.now(),
      auteurId: userId,
    );
    var ok = true;
    if (_modeEdition) {
      ok = await _repo.modifierAvis(avis, userId);
    } else {
      await _repo.creerAvis(avis);
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _enregistrement = false);
      afficherMessage(context, 'Vous ne pouvez modifier que vos propres avis',
          erreur: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: _modeEdition ? 'Modifier mon avis' : 'Donner un avis',
      corps: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ChampChoix<CibleAvis>(
            label: 'Type de service',
            icone: Icons.category_outlined,
            valeur: _cible,
            items: [
              for (final c in CibleAvis.values)
                DropdownMenuItem<CibleAvis>(value: c, child: Text(c.libelle)),
            ],
            onChange: (c) {
              if (c != null) _changerType(c);
            },
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<(int, String)>>(
            future: _cibles,
            builder: (context, snap) {
              if (snap.hasError) {
                return _bandeau('Chargement impossible : ${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(color: AppColors.teal),
                );
              }
              final liste = snap.data!;
              if (liste.isEmpty) {
                return _bandeau(
                    'Aucun service de ce type pour l\'instant. Ajoutez-en d\'abord dans son module.');
              }
              final valeur = liste.any((e) => e.$1 == _cibleId) ? _cibleId : null;
              return ChampChoix<int>(
                label: 'Service concerné',
                icone: Icons.sell_outlined,
                valeur: valeur,
                erreur: (_tentative && valeur == null) ? 'Choisissez un service' : null,
                items: [
                  for (final e in liste)
                    DropdownMenuItem<int>(
                      value: e.$1,
                      child: Text(e.$2, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChange: (id) => setState(() => _cibleId = id),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text('Votre note',
              style: TextStyle(
                  color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i sur 5',
                  iconSize: 38,
                  onPressed: () => setState(() => _note = i),
                  icon: Icon(
                    i <= _note ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.orange,
                  ),
                ),
            ],
          ),
          if (_tentative && _note < 1)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Donnez une note de 1 à 5',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          ChampTexte(
            controller: _commentaire,
            label: 'Commentaire (facultatif)',
            icone: Icons.chat_bubble_outline,
            lignes: 4,
            capitalisation: TextCapitalization.sentences,
          ),
          const SizedBox(height: 28),
          BoutonPrincipal(
            libelle: _modeEdition ? 'Enregistrer' : 'Publier mon avis',
            icone: Icons.send_outlined,
            onPressed: _enregistrement ? null : _enregistrer,
          ),
          const SizedBox(height: 12),
          BoutonSecondaire(
            libelle: 'Annuler',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _bandeau(String texte) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
        child: Text(texte,
            style: const TextStyle(
                color: AppColors.orangeText, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}
