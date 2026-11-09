import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../forum_repository.dart';
import '../models/sujet_forum.dart';
import 'sujet_form_screen.dart';

/// Un fil de discussion : le sujet, ses réponses, et la zone pour répondre.
class SujetDetailScreen extends StatefulWidget {
  final int sujetId;

  const SujetDetailScreen({super.key, required this.sujetId});

  @override
  State<SujetDetailScreen> createState() => _SujetDetailScreenState();
}

class _Detail {
  final SujetForum sujet;
  final List<ReponseForum> reponses;
  final int? userId;

  const _Detail(this.sujet, this.reponses, this.userId);
}

class _SujetDetailScreenState extends State<SujetDetailScreen> {
  final _repo = ForumRepository();
  final _reponse = TextEditingController();
  late Future<_Detail?> _futur;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
  }

  @override
  void dispose() {
    _reponse.dispose();
    super.dispose();
  }

  Future<_Detail?> _charger() async {
    final sujet = await _repo.sujet(widget.sujetId);
    if (sujet == null) return null;
    final reponses = await _repo.reponses(widget.sujetId);
    final userId = await SessionService.instance.utilisateurId();
    return _Detail(sujet, reponses, userId);
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _charger();
    });
    await _futur;
  }

  Future<void> _envoyerReponse(int userId) async {
    final texte = _reponse.text.trim();
    if (texte.length < 2) return;
    setState(() => _envoi = true);
    await _repo.ajouterReponse(
        sujetId: widget.sujetId, auteurId: userId, contenu: texte);
    if (!mounted) return;
    _reponse.clear();
    setState(() => _envoi = false);
    await _recharger();
  }

  Future<void> _supprimerReponse(ReponseForum r, int userId) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer cette réponse ?',
      message: 'Cette action est définitive.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerReponse(r.id!, userId);
    if (!mounted) return;
    await _recharger();
  }

  Future<void> _modifierSujet(SujetForum s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SujetFormScreen(sujet: s)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _supprimerSujet(int userId) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer cette discussion ?',
      message: 'Toutes ses réponses seront supprimées aussi.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerSujet(widget.sujetId, userId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Detail?>(
      future: _futur,
      builder: (context, snap) {
        final detail = snap.data;
        final estAuteur =
            detail != null && detail.userId == detail.sujet.auteurId;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            scrolledUnderElevation: 0,
            title: Text(detail?.sujet.titre ?? 'Discussion',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (estAuteur)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _modifierSujet(detail!.sujet),
                ),
              if (estAuteur)
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimerSujet(detail!.userId!),
                ),
            ],
          ),
          body: _corps(snap, detail),
          bottomNavigationBar: (detail?.userId == null)
              ? null
              : _barreReponse(detail!.userId!),
        );
      },
    );
  }

  Widget _corps(AsyncSnapshot<_Detail?> snap, _Detail? detail) {
    if (snap.hasError) {
      return EtatVideModule(
        icone: Icons.error_outline,
        titre: 'Chargement impossible',
        message: '${snap.error}',
      );
    }
    if (!snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      return const EtatVideModule(
        icone: Icons.search_off,
        titre: 'Discussion introuvable',
        message: 'Elle a peut-être été supprimée.',
      );
    }
    final s = detail.sujet;
    return RefreshIndicator(
      onRefresh: _recharger,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              CarteModule(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.titre,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(s.contenu,
                        style: const TextStyle(
                            color: AppColors.navy, fontSize: 15, height: 1.4)),
                    const SizedBox(height: 12),
                    Text('${s.nomAuteur ?? 'Anonyme'} · ${dateCourte(s.creeLe)}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              EnteteSection(titre: 'Réponses (${detail.reponses.length})'),
              const SizedBox(height: 10),
              if (detail.reponses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Aucune réponse pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grey)),
                )
              else
                ...[
                  for (final r in detail.reponses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _reponseCarte(r, detail.userId),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _reponseCarte(ReponseForum r, int? userId) {
    final laMienne = userId != null && r.auteurId == userId;
    return CarteModule(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.nomAuteur ?? 'Anonyme',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              if (laMienne)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Supprimer',
                    iconSize: 18,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _supprimerReponse(r, userId!),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.contenu,
              style: const TextStyle(color: AppColors.navy, fontSize: 15, height: 1.4)),
          const SizedBox(height: 8),
          Text(dateCourte(r.creeLe),
              style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _barreReponse(int userId) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _reponse,
                minLines: 1,
                maxLines: 4,
                decoration: decorationUi('Votre réponse'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Envoyer',
              style: IconButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: _envoi ? null : () => _envoyerReponse(userId),
              icon: const Icon(Icons.send, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
