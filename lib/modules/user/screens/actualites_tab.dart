import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../actualite_fil.dart';
import '../admin_repository.dart';
import '../commentaire.dart';
import '../commentaire_repository.dart';
import '../notification_repository.dart';
import '../historique.dart';
import '../historique_repository.dart';
import '../partage_repository.dart';
import '../participation_repository.dart';
import '../reaction_commentaire_repository.dart';
import '../reaction_repository.dart';
import '../role.dart';
import '../sondage.dart';
import '../sondage_repository.dart';
import '../user_repository.dart';
import '../utilisateur.dart';
import 'actualite_form_screen.dart';
import 'messenger_screen.dart';
import 'notifications_screen.dart';
import 'widgets_accueil.dart';

/// Onglet « Actualités » : fil commun à tous les utilisateurs connectés.
/// Chacun peut y publier, et modifier ou supprimer ses propres publications
/// (l'administrateur peut tout gérer). Avec recherche et filtre par catégorie.
class ActualitesTab extends StatefulWidget {
  final Utilisateur utilisateur;

  const ActualitesTab({super.key, required this.utilisateur});

  @override
  State<ActualitesTab> createState() => _ActualitesTabState();
}

class _ActualitesTabState extends State<ActualitesTab> {
  late Future<List<Actualite>> _future;
  String _recherche = '';
  CategorieActualite? _categorie;

  @override
  void initState() {
    super.initState();
    _future = UserRepository().actualites();
  }

  /// Comme SyrWriteHub (_loadFeed) : le fil se recharge à chaque fois
  /// que l'onglet redevient visible (posts de l'autre compte inclus).
  @override
  void activate() {
    super.activate();
    _future = UserRepository().actualites();
  }

  Future<void> _recharger() async {
    // Bloc et non fléchée : setState ne doit pas renvoyer de Future.
    setState(() {
      _future = UserRepository().actualites();
    });
    await _future;
  }

  Future<void> _publier() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ActualiteFormScreen()),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Actualité publiée');
      await _recharger();
    }
  }

  Future<void> _modifier(Actualite a) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ActualiteFormScreen(actualite: a)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _supprimer(Actualite a) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce post ?',
      message: '« ${a.titre} » restera archivé dans l’historique.',
    );
    if (!ok || !mounted) return;
    await AdminRepository().supprimerActualite(a.id!);
    if (!mounted) return;
    afficherMessage(context, 'Post supprimé');
    await _recharger();
  }

  bool _peutModifier(Actualite a) => FilActualites.peutModifier(
        a,
        utilisateurId: widget.utilisateur.id,
        role: widget.utilisateur.role,
      );

  /// En ouvrant un post du fil : son contenu, puis son historique
  /// (pour l'auteur), avec bouton « Restaurer ».
  Future<void> _ouvrirPost(Actualite a) async {
    final estAuteur = a.auteurId == widget.utilisateur.id;
    final versions = estAuteur
        ? await HistoriqueRepository().versions(a.id!, widget.utilisateur.id!)
        : <VersionPost>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a.titre),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(a.contenu),
              if (estAuteur) ...[
                const SizedBox(height: 16),
                const Text('Historique',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (versions.isEmpty) const Text('Aucune version archivée.'),
                for (final v in versions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.titre,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '« ${v.contenu} » — ${v.action} le ${v.creeLe.day}/${v.creeLe.month}/${v.creeLe.year}'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _publier,
      ),
      body: RefreshIndicator(
        onRefresh: _recharger,
        child: FutureBuilder<List<Actualite>>(
          future: _future,
          builder: (context, snap) {
            final toutes = snap.data ?? const <Actualite>[];
            final items = FilActualites.filtrer(
              toutes,
              role: widget.utilisateur.role,
              recherche: _recherche,
              categorie: _categorie,
            );
            final Widget contenu = !snap.hasData
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : items.isEmpty
                    ? const EtatVideModule(
                        icone: Icons.newspaper_outlined,
                        titre: 'Aucune actualité',
                        message: '',
                      )
                    : Column(
                        children: [
                          for (final a in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CarteActualite(
                                actualite: a,
                                utilisateur: widget.utilisateur,
                                onModifier: _modifier,
                                onSupprimer: _supprimer,
                                onOuvrir: _ouvrirPost,
                              ),
                            ),
                        ],
                      );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.paddingOf(context).top + 16, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.teal, AppColors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Actualités',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Messages',
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: AppColors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessengerScreen(utilisateur: widget.utilisateur),
                          ),
                        ),
                      ),
                      _ClocheNotifications(utilisateur: widget.utilisateur),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Composer(
                  utilisateur: widget.utilisateur,
                  onPublier: _publier,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: _Stories(
                    toutes: toutes,
                    onChoisir: (nom) => setState(() => _recherche = nom),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: decorationUi('Rechercher', icone: Icons.search),
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _recherche = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _pastille('Toutes', _categorie == null, () => setState(() => _categorie = null)),
                      for (final c in CategorieActualite.values)
                        _pastille(c.libelle, _categorie == c, () => setState(() => _categorie = c)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                contenu,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pastille(String libelle, bool selectionnee, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(libelle),
        selected: selectionnee,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.tealLight,
        labelStyle: TextStyle(
          color: selectionnee ? AppColors.teal : AppColors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// « Quoi de neuf ? » comme Facebook : photo + champ qui ouvre le formulaire.
class _Composer extends StatelessWidget {
  final Utilisateur utilisateur;
  final VoidCallback onPublier;

  const _Composer({required this.utilisateur, required this.onPublier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.teal, shape: BoxShape.circle),
            child: utilisateur.photo == null
                ? Text(utilisateur.initiales,
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w800))
                : ClipOval(
                    child: Image.memory(
                      base64Decode(utilisateur.photo!),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onPublier,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Quoi de neuf, ${utilisateur.prenom} ?',
                    style: const TextStyle(color: AppColors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stories : photos des auteurs récents (toucher filtre le fil sur eux).
class _Stories extends StatelessWidget {
  final List<Actualite> toutes;
  final ValueChanged<String> onChoisir;

  const _Stories({required this.toutes, required this.onChoisir});

  @override
  Widget build(BuildContext context) {
    final vus = <int?>{};
    final auteurs = <Actualite>[];
    for (final a in toutes) {
      if (a.auteurId == null || !vus.add(a.auteurId)) continue;
      auteurs.add(a);
      if (auteurs.length >= 8) break;
    }
    if (auteurs.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: auteurs.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final d = auteurs[i];
        return InkWell(
          onTap: () => onChoisir(d.auteurNom ?? ''),
          borderRadius: BorderRadius.circular(40),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.teal,
                    AppColors.orange,
                  ]),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppColors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 27,
                    backgroundColor: AppColors.teal,
                    backgroundImage: d.auteurPhoto == null
                        ? null
                        : MemoryImage(base64Decode(d.auteurPhoto!)),
                    child: d.auteurPhoto == null
                        ? Text(
                            (d.auteurNom ?? '?').split(' ').first.isEmpty
                                ? '?'
                                : (d.auteurNom ?? '?').split(' ').first[0],
                            style: const TextStyle(
                                color: AppColors.white, fontWeight: FontWeight.w800),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 68,
                child: Text(
                  (d.auteurNom ?? '').split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cloche des notifications avec pastille du nombre de non-lues.
class _ClocheNotifications extends StatefulWidget {
  final Utilisateur utilisateur;
  const _ClocheNotifications({required this.utilisateur});

  @override
  State<_ClocheNotifications> createState() => _ClocheNotificationsState();
}

class _ClocheNotificationsState extends State<_ClocheNotifications> {
  late Future<int> _nonLues;

  @override
  void initState() {
    super.initState();
    _nonLues = NotificationRepository().nonLues(widget.utilisateur.id!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _nonLues,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return Stack(
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined, color: AppColors.white),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(utilisateur: widget.utilisateur),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _nonLues = NotificationRepository().nonLues(widget.utilisateur.id!);
                });
              },
            ),
            if (n > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle),
                  child: Text('$n',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Une publication du fil, avec ses commentaires (type Facebook).
/// Seul l'auteur voit les boutons modifier/supprimer de sa publication
/// et de ses propres commentaires.
class _CarteActualite extends StatefulWidget {
  final Actualite actualite;
  final Utilisateur utilisateur;
  final ValueChanged<Actualite> onModifier;
  final ValueChanged<Actualite> onSupprimer;
  final ValueChanged<Actualite> onOuvrir;

  const _CarteActualite({
    required this.actualite,
    required this.utilisateur,
    required this.onModifier,
    required this.onSupprimer,
    required this.onOuvrir,
  });

  @override
  State<_CarteActualite> createState() => _CarteActualiteState();
}

class _CarteActualiteState extends State<_CarteActualite> {
  final _repo = CommentaireRepository();
  final _reactions = ReactionRepository();
  final _sondages = SondageRepository();
  final _saisie = TextEditingController();
  final _cleBouton = GlobalKey();
  final _reponseCtrl = TextEditingController();
  bool _afficher = false;
  bool _pop = false;
  int? _reponseAffiche;
  late Future<List<CommentaireActualite>> _commentaires;
  late Future<int> _nombre;
  late Future<int> _likes;
  late Future<String?> _maReaction;
  late Future<List<ResultatSondage>> _sondage;

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  void _recharger() {
    _commentaires = _repo.lister(widget.actualite.id!);
    _nombre = _repo.compter(widget.actualite.id!);
    _likes = _reactions.compter(widget.actualite.id!);
    _maReaction = _reactions.maReaction(widget.actualite.id!, widget.utilisateur.id!);
    _sondage = _sondages.resultats(widget.actualite.id!, utilisateurId: widget.utilisateur.id);
    _rechargerParticipation();
  }

  // --- Réactions, sondage, partage ---

  /// Choix d'une réaction (clic = J'aime, clic long = menu emoji).
  Future<void> _choisirReaction(String type) async {
    // Petit « pop » de confirmation (scalaire 1.4 → 1.0).
    setState(() => _pop = true);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _pop = false);
    });
    final apres = await _reactions.choisir(widget.actualite.id!, widget.utilisateur.id!, type);
    if (!mounted) return;
    // Notifie l'auteur seulement quand on ajoute (pas quand on retire).
    if (apres != null && widget.actualite.auteurId != null) {
      await NotificationRepository().notifier(
        destinataireId: widget.actualite.auteurId!,
        acteurId: widget.utilisateur.id!,
        acteurNom: widget.utilisateur.nomComplet,
        type: 'reaction',
        actualiteId: widget.actualite.id,
        texte:
            '${widget.utilisateur.nomComplet} a réagi « ${ReactionTypes.labelDe(type)} » à ton post « ${widget.actualite.titre} »',
      );
    }
    if (!mounted) return;
    setState(_recharger);
  }

  /// Petit menu déroulant juste à côté du bouton (comme Facebook) :
  /// il s'affiche près du bouton, jamais en plein écran.
  Future<void> _menuReactions(String? actuel) async {
    final boite = _cleBouton.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null || !boite.hasSize) return;
    final repo = boite.localToGlobal(Offset.zero);
    final rect = RelativeRect.fromLTRB(
      repo.dx,
      repo.dy - 240,
      MediaQuery.of(context).size.width - repo.dx - boite.size.width,
      MediaQuery.of(context).size.height - repo.dy,
    );
    final choix = await showMenu<String>(
      context: context,
      position: rect,
      items: [
        for (final type in ReactionTypes.values)
          PopupMenuItem(
            value: type,
            child: Row(
              children: [
                Text(ReactionTypes.emojiDe(type),
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  ReactionTypes.labelDe(type),
                  style: TextStyle(
                    fontWeight:
                        actuel == type ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                if (actuel == type) ...[
                  const Spacer(),
                  const Icon(Icons.check_circle, size: 18, color: AppColors.teal),
                ],
              ],
            ),
          ),
        if (actuel != null)
          const PopupMenuItem(
            value: '',
            child: Text('Retirer'),
          ),
      ],
    );
    if (choix == null || !mounted) return;
    if (choix.isEmpty) {
      await _choisirReaction(actuel!); // même type = retire
    } else {
      await _choisirReaction(choix);
    }
  }

  Future<void> _voter(int optionId) async {
    await _sondages.voter(
      actualiteId: widget.actualite.id!,
      optionId: optionId,
      utilisateurId: widget.utilisateur.id!,
    );
    if (widget.actualite.auteurId != null) {
      await NotificationRepository().notifier(
        destinataireId: widget.actualite.auteurId!,
        acteurId: widget.utilisateur.id!,
        acteurNom: widget.utilisateur.nomComplet,
        type: 'sondage',
        actualiteId: widget.actualite.id,
        texte: '${widget.utilisateur.nomComplet} a voté à ton sondage « ${widget.actualite.titre} »',
      );
    }
    if (!mounted) return;
    setState(_recharger);
  }

  // --- Post annonce : participer ---

  final _participations = ParticipationRepository();
  late Future<int> _participants;
  late Future<bool> _participe;

  void _rechargerParticipation() {
    _participants = _participations.compter(widget.actualite.id!);
    _participe = _participations.participe(widget.actualite.id!, widget.utilisateur.id!);
  }

  Future<void> _basculerParticipation() async {
    await _participations.basculer(
      actualiteId: widget.actualite.id!,
      utilisateurId: widget.utilisateur.id!,
      auteurId: widget.actualite.auteurId,
      acteurNom: widget.utilisateur.nomComplet,
    );
    if (!mounted) return;
    setState(_rechargerParticipation);
  }

  final _partages = PartageRepository();

  /// Partage réel : enregistré une seule fois, visible dans le profil
  /// du partageur (« partagé de X »), l'auteur est notifié.
  /// Le texte est aussi copié pour coller ailleurs.
  Future<void> _partager() async {
    final a = widget.actualite;
    final deja = await _partages.aPartage(a.id!, widget.utilisateur.id!);
    if (!deja) {
      await _partages.basculer(
        actualiteId: a.id!,
        utilisateurId: widget.utilisateur.id!,
        auteurId: a.auteurId,
        acteurNom: widget.utilisateur.nomComplet,
      );
    }
    await Clipboard.setData(ClipboardData(text: '${a.titre}\n${a.contenu}'));
    if (!mounted) return;
    afficherMessage(context, 'Partagé !');
    setState(_recharger);
  }

  @override
  void dispose() {
    _saisie.dispose();
    _reponseCtrl.dispose();
    super.dispose();
  }

  // --- Répondre à un commentaire (auteur seul pour modifier/supprimer) ---

  void _repondre(CommentaireActualite c) {
    setState(() => _reponseAffiche = c.id);
  }

  Future<void> _envoyerReponse(CommentaireActualite c) async {
    final texte = _reponseCtrl.text.trim();
    if (texte.isEmpty) return;
    await _repo.ajouter(
      actualiteId: widget.actualite.id!,
      parentId: c.id,
      auteurId: widget.utilisateur.id!,
      auteurNom: widget.utilisateur.nomComplet,
      contenu: texte,
    );
    // L'auteur du commentaire reçoit une notification.
    if (c.auteurId != null) {
      await NotificationRepository().notifier(
        destinataireId: c.auteurId!,
        acteurId: widget.utilisateur.id!,
        acteurNom: widget.utilisateur.nomComplet,
        type: 'commentaire',
        actualiteId: widget.actualite.id,
        texte: '${widget.utilisateur.nomComplet} a répondu à ton commentaire',
      );
    }
    if (!mounted) return;
    _reponseCtrl.clear();
    setState(() {
      _reponseAffiche = null;
      _recharger();
    });
  }

  Future<void> _menuReactionCommentaire(CommentaireActualite c, Offset position) async {
    final choix = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 240,
        MediaQuery.of(context).size.width - position.dx - 10,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        for (final type in ReactionTypes.values)
          PopupMenuItem(
            value: type,
            child: Row(children: [
              Text(ReactionTypes.emojiDe(type), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(ReactionTypes.labelDe(type)),
            ]),
          ),
      ],
    );
    if (choix == null || !mounted) return;
    await ReactionCommentaireRepository()
        .choisir(c.id!, widget.utilisateur.id!, choix);
    if (!mounted) return;
    setState(_recharger);
  }

  Future<void> _ajouter() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty) return;
    await _repo.ajouter(
      actualiteId: widget.actualite.id!,
      auteurId: widget.utilisateur.id!,
      auteurNom: widget.utilisateur.nomComplet,
      contenu: texte,
    );
    if (widget.actualite.auteurId != null) {
      await NotificationRepository().notifier(
        destinataireId: widget.actualite.auteurId!,
        acteurId: widget.utilisateur.id!,
        acteurNom: widget.utilisateur.nomComplet,
        type: 'commentaire',
        actualiteId: widget.actualite.id,
        texte: '${widget.utilisateur.nomComplet} a commenté ton post « ${widget.actualite.titre} »',
      );
    }
    if (!mounted) return;
    _saisie.clear();
    setState(_recharger);
  }

  Future<void> _modifierCommentaire(CommentaireActualite c) async {
    final controle = TextEditingController(text: c.contenu);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le commentaire'),
        content: TextField(
          controller: controle,
          maxLines: 3,
          autofocus: true,
          decoration: decorationUi('Commentaire'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final fait = await _repo.modifier(c.id!, widget.utilisateur.id!, controle.text);
    if (!mounted) return;
    if (!fait) {
      afficherMessage(context, 'Action non autorisée', erreur: true);
      return;
    }
    setState(_recharger);
  }

  Future<void> _supprimerCommentaire(CommentaireActualite c) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce commentaire ?',
      message: '« ${c.contenu} » sera définitivement supprimé.',
    );
    if (!ok || !mounted) return;
    final fait = await _repo.supprimer(c.id!, widget.utilisateur.id!);
    if (!mounted) return;
    if (!fait) {
      afficherMessage(context, 'Action non autorisée', erreur: true);
      return;
    }
    setState(_recharger);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actualite;
    final peut = FilActualites.peutModifier(a, utilisateurId: widget.utilisateur.id);
    return CarteModule(
      onTap: () => widget.onOuvrir(a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
                child: a.auteurPhoto == null
                    ? Text(
                        (a.auteurNom ?? '?').split(' ').map((m) => m.isEmpty ? '' : m[0]).join().toUpperCase().substring(0, (a.auteurNom ?? '?').split(' ').length > 1 ? 2 : 1),
                        style: const TextStyle(
                            color: AppColors.white, fontWeight: FontWeight.w800),
                      )
                    : ClipOval(
                        child: Image.memory(
                          base64Decode(a.auteurPhoto!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.auteurNom ?? 'Travel Platform',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                        if (a.auteurRole != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tealLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              Role.depuis(a.auteurRole!).libelle,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      FilActualites.tempsRelatif(a.datePublication),
                      style: const TextStyle(fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(a.titre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (peut) ...[
                IconButton(
                  tooltip: 'Historique',
                  icon: const Icon(Icons.history, color: AppColors.grey),
                  onPressed: () => widget.onOuvrir(a),
                ),
                IconButton(
                  tooltip: a.epingle ? 'Retirer l’épingle' : 'Épingler en haut du fil',
                  icon: Icon(
                    a.epingle
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: AppColors.teal,
                  ),
                  onPressed: () async {
                    await AdminRepository().epingler(
                        a.id!, widget.utilisateur.id!, !a.epingle);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(a.epingle
                            ? 'Post retiré des épinglés'
                            : 'Post épinglé en haut du fil'),
                      ));
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                  onPressed: () => widget.onModifier(a),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => widget.onSupprimer(a),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (a.contenu.trim().isNotEmpty)
            Text(a.contenu,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          if (a.photo != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                base64Decode(a.photo!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            Pastille(libelle: a.categorie.libelle, valeur: 'valide'),
            Pastille(libelle: a.audience.libelle, valeur: 'ouverte'),
            if (a.epingle) Pastille(libelle: 'Épinglé', valeur: 'valide'),
          ]),
          if (a.typePost == TypePost.annonce) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: AppColors.teal),
                      SizedBox(width: 8),
                      Text('Annonce',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (a.dateEvenement != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Le ${a.dateEvenement!.day}/${a.dateEvenement!.month}/${a.dateEvenement!.year}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (a.lieu != null && a.lieu!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Lieu : ${a.lieu!}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 10),
                  FutureBuilder<bool>(
                    future: _participe,
                    builder: (context, snapParticipe) => FutureBuilder<int>(
                      future: _participants,
                      builder: (context, snapNb) => OutlinedButton.icon(
                        onPressed: _basculerParticipation,
                        icon: Icon(
                          (snapParticipe.data ?? false)
                              ? Icons.check
                              : Icons.event_available_outlined,
                          size: 18,
                        ),
                        label: Text((snapParticipe.data ?? false)
                            ? 'Tu participes (${snapNb.data ?? 0})'
                            : 'Participer (${snapNb.data ?? 0})'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          FutureBuilder<List<ResultatSondage>>(
            future: _sondage,
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.poll_outlined, size: 18, color: AppColors.teal),
                      SizedBox(width: 8),
                      Text('Sondage',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final r in snap.data!) _ligneSondage(r),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Bouton réaction : J'aime + flèche (menu au clic, comme SyrWriteHub).
              FutureBuilder<String?>(
                future: _maReaction,
                builder: (context, snapReaction) => FutureBuilder<int>(
                  future: _likes,
                  builder: (context, snapLikes) {
                    final reaction = snapReaction.data;
                    final total = snapLikes.data ?? 0;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: _pop ? 1.4 : 1.0, end: _pop ? 1.4 : 1.0),
                      duration: const Duration(milliseconds: 140),
                      builder: (context, echelle, enfant) => Transform.scale(
                        scale: echelle,
                        child: enfant,
                      ),
                      child: TextButton.icon(
                        key: _cleBouton,
                        onPressed: () => _menuReactions(reaction),
                        icon: Text(
                          reaction == null ? '🤍' : ReactionTypes.emojiDe(reaction!),
                          style: const TextStyle(fontSize: 18),
                        ),
                        label: Row(
                          children: [
                            Text(
                              reaction == null
                                  ? "J'aime · $total"
                                  : '${ReactionTypes.labelDe(reaction!)} · $total',
                              style: TextStyle(
                                fontSize: 13,
                                color: reaction == null
                                    ? AppColors.grey
                                    : AppColors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: reaction == null
                                  ? AppColors.grey
                                  : AppColors.teal,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              FutureBuilder<int>(
                future: _nombre,
                builder: (context, snap) => TextButton.icon(
                  onPressed: () => setState(() => _afficher = !_afficher),
                  icon: const Icon(Icons.mode_comment_outlined, size: 18),
                  label: Text('${snap.data ?? 0}'),
                ),
              ),
              TextButton.icon(
                onPressed: _partager,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Partager'),
              ),
              if (a.auteurId != null && a.auteurId != widget.utilisateur.id)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessengerScreen(
                        utilisateur: widget.utilisateur,
                        cibleId: a.auteurId,
                        cibleNom: a.auteurNom,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message'),
                ),
            ],
          ),
          if (_afficher) ...[
            FutureBuilder<List<CommentaireActualite>>(
              future: _commentaires,
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                return Column(
                  children: [
                    for (final c in snap.data!) _ligneCommentaire(c),
                    if (snap.data!.isNotEmpty) const SizedBox(height: 8),
                  ],
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _saisie,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ajouter(),
                    decoration: decorationUi('Écrire un commentaire…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Envoyer',
                  icon: const Icon(Icons.send, color: AppColors.teal),
                  onPressed: _ajouter,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Une option de sondage : cliquable avant le vote, barre de résultat après.
  Widget _ligneSondage(ResultatSondage r) {
    final dejaVote = r.choisi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _voter(r.option.id!),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: dejaVote ? AppColors.tealLight : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.option.libelle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  if (dejaVote) ...[
                    const Icon(Icons.check_circle, size: 16, color: AppColors.teal),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: r.pourcentage / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${r.votes} vote${r.votes > 1 ? 's' : ''} · ${r.pourcentage.toStringAsFixed(0)} %',
                style: const TextStyle(fontSize: 12, color: AppColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneCommentaire(CommentaireActualite c, {int niveau = 0}) {
    final aMoi = FilActualites.peutModifierCommentaire(c, utilisateurId: widget.utilisateur.id);
    final reactions = ReactionCommentaireRepository();
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: niveau * 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: aMoi ? AppColors.tealLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(c.auteurNom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                          if (c.auteurRole != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                Role.depuis(c.auteurRole!).libelle,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                if (aMoi) ...[
                  IconButton(
                    tooltip: 'Modifier',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.teal),
                    onPressed: () => _modifierCommentaire(c),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    onPressed: () => _supprimerCommentaire(c),
                  ),
                ],
              ],
            ),
            Text(c.contenu, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            // Réaction au commentaire + répondre (tout le monde).
            Row(
              children: [
                FutureBuilder<String?>(
                  future: reactions.maReaction(c.id!, widget.utilisateur.id!),
                    builder: (context, snapMa) => FutureBuilder<int>(
                    future: reactions.compter(c.id!),
                    builder: (context, snapNb) => InkWell(
                      onTapDown: (detail) async {
                        await _menuReactionCommentaire(c, detail.globalPosition);
                        if (mounted) setState(_recharger);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '${snapMa.data == null ? '🤍' : ReactionTypes.emojiDe(snapMa.data!)} ${snapNb.data ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: snapMa.data == null ? AppColors.grey : AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _repondre(c),
                  child: const Text('Répondre', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            // Fil de réponses (un niveau, comme SyrWriteHub).
            FutureBuilder<List<CommentaireActualite>>(
              future: CommentaireRepository().reponses(c.id!),
              builder: (context, snapRep) {
                final reponses = snapRep.data ?? const <CommentaireActualite>[];
                if (reponses.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    for (final r in reponses) _ligneCommentaire(r, niveau: niveau + 1),
                  ],
                );
              },
            ),
            if (_reponseAffiche == c.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reponseCtrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _envoyerReponse(c),
                        decoration: decorationUi('Répondre…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Envoyer',
                      icon: const Icon(Icons.send, color: AppColors.teal),
                      onPressed: () => _envoyerReponse(c),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pastille(String libelle, bool selectionnee, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(libelle),
        selected: selectionnee,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.tealLight,
        labelStyle: TextStyle(
          color: selectionnee ? AppColors.teal : AppColors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
