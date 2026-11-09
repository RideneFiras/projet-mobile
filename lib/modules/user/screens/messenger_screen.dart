import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../message_prive.dart';
import '../message_repository.dart';
import '../user_repository.dart';
import '../utilisateur.dart';
import 'appel_screen.dart';

/// Messenger du fil d'actualité (comme Facebook) : messages privés entre
/// utilisateurs. On ouvre une conversation depuis un post (bouton
/// « Message » sur le post d'un autre) ou depuis cette liste.
class MessengerScreen extends StatefulWidget {
  final Utilisateur utilisateur;
  /// Si renseigné (depuis le bouton « Message » d'un post), la conversation
  /// avec cet auteur s'ouvre directement — comme SyrWriteHub.
  final int? cibleId;
  final String? cibleNom;

  const MessengerScreen({
    super.key,
    required this.utilisateur,
    this.cibleId,
    this.cibleNom,
  });

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  final _repo = MessageRepository();
  late Future<List<Conversation>> _conversations;

  @override
  void initState() {
    super.initState();
    _recharger();
    // Depuis un post : on entre directement dans la conversation.
    if (widget.cibleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _FilConversation(
              moi: widget.utilisateur,
              autreId: widget.cibleId!,
              autreNom: widget.cibleNom ?? 'Utilisateur',
            ),
          ),
        );
      });
    }
  }

  void _recharger() {
    _conversations = _repo.conversations(widget.utilisateur.id!);
  }

  Future<void> _ouvrir(Conversation c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FilConversation(
          moi: widget.utilisateur,
          autreId: c.autreId,
          autreNom: c.autreNom,
        ),
      ),
    );
    if (!mounted) return;
    setState(_recharger);
  }

  Future<void> _nouveau() async {
    final contacts = await UserRepository()
        .tousLesUtilisateurs()
        .then((l) => l.where((u) => u.id != widget.utilisateur.id).toList());
    if (!mounted) return;
    if (contacts.isEmpty) {
      afficherMessage(context, 'Aucun autre compte pour l’instant', erreur: true);
      return;
    }
    final choisi = await showDialog<Utilisateur>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau message'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) => ListTile(
              leading: CircleAvatar(child: Text(contacts[i].initiales)),
              title: Text(contacts[i].nomComplet),
              subtitle: Text(contacts[i].role.libelle),
              onTap: () => Navigator.pop(ctx, contacts[i]),
            ),
          ),
        ),
      ),
    );
    if (choisi == null || !mounted) return;
    await _ouvrir(Conversation(
      autreId: choisi.id!,
      autreNom: choisi.nomComplet,
      dernierMessage: '',
      dernierDate: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Messenger',
      actions: [
        IconButton(
          tooltip: 'Nouveau message',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _nouveau,
        ),
      ],
      corps: FutureBuilder<List<Conversation>>(
        future: _conversations,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = snap.data!;
          if (liste.isEmpty) {
            return const EtatVideModule(
              icone: Icons.chat_bubble_outline,
              titre: 'Aucune conversation',
              message: 'Depuis un post, touchez « Message » pour écrire à son auteur.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final c = liste[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CarteModule(
                  onTap: () => _ouvrir(c),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.teal,
                        child: Text(
                          c.autreNom.split(' ').map((m) => m.isEmpty ? '' : m[0]).join().toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.autreNom,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              c.dernierMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Fil de messages d'une conversation (bulles, comme Messenger).
class _FilConversation extends StatefulWidget {
  final Utilisateur moi;
  final int autreId;
  final String autreNom;

  const _FilConversation({
    required this.moi,
    required this.autreId,
    required this.autreNom,
  });

  @override
  State<_FilConversation> createState() => _FilConversationState();
}

class _FilConversationState extends State<_FilConversation> {
  final _repo = MessageRepository();
  final _saisie = TextEditingController();
  final _lecteur = AudioPlayer();
  late Future<List<MessagePrive>> _messages;
  bool _enregistre = false;
  bool _emojiVisible = false;
  final AudioRecorder _recorder = AudioRecorder();

  static const _emojis = [
    '👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '🔥', '👏', '🙏',
    '😍', '😎', '🤔', '👌', '💯', '✨', '🌟', '🎶', '☀️', '🌙',
    '⭐', '💖', '💙', '💚', '💛', '🧡', '💜', '🖤', '💔', '💕',
    '😘', '😗', '😙', '😚', '🤗', '🤩', '🥳', '😇', '🥺', '😋',
    '😛', '😜', '🤪', '😝', '🤑)', '🤭', '🤫', '🤮', '🤒', '🤕',
    '😷', '🤒', '🥵', '🥶', '😱', '😨', '😰', '😥', '😭', '😤',
    '😠', '😤', '🤯', '😳', '🥴', '😏', '😒', '🙄', '😬', '🤥',
    '🙂', '🙃', '😉', '😊', '😃', '😄', '😁', '😆', '😅', '🤣',
    '😊', '☺️', '😚', '😙', '🥰', '😘', '😗', '😋', '😛', '😝',
  ];

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  void _recharger() {
    _messages = _repo.conversation(widget.moi.id!, widget.autreId);
  }

  @override
  void dispose() {
    _saisie.dispose();
    _lecteur.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty) return;
    await _repo.envoyer(
      expediteurId: widget.moi.id!,
      destinataireId: widget.autreId,
      contenu: texte,
    );
    if (!mounted) return;
    _saisie.clear();
    setState(_recharger);
  }

  Future<void> _envoyerPhoto() async {
    final fichier = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (fichier == null || !mounted) return;
    final octets = await fichier.readAsBytes();
    await _repo.envoyer(
      expediteurId: widget.moi.id!,
      destinataireId: widget.autreId,
      contenu: base64Encode(octets),
      type: 'image',
    );
    if (!mounted) return;
    setState(_recharger);
  }

  /// Vocal : premier clic = enregistre (vrai fichier temporaire),
  /// deuxième clic = envoie. Sur web, le plugin n'existe pas
  /// (MissingPluginException) : on bloque proprement avec un message.
  Future<void> _envoyerVocal() async {
    if (kIsWeb) {
      afficherMessage(context, 'Messages vocaux : passe sur Android pour l’enregistrement');
      return;
    }
    final recorder = _recorder;
    if (!_enregistre) {
      try {
        final autorisation = await recorder.hasPermission();
        if (!autorisation) {
          if (mounted) {
            afficherMessage(context, 'Micro refusé : autorisez-le dans les paramètres de l’app', erreur: true);
          }
          return;
        }
        final dossier = await getTemporaryDirectory();
        final chemin = '${dossier.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: chemin);
        if (mounted) setState(() => _enregistre = true);
      } on MissingPluginException {
        if (mounted) {
          afficherMessage(context, 'Plugin absent : refais flutter clean puis flutter run', erreur: true);
        }
      } on PlatformException catch (e) {
        if (mounted) {
          afficherMessage(context, 'Micro impossible (${e.code}) : ${e.message}', erreur: true);
        }
      } catch (e) {
        if (mounted) {
          afficherMessage(context, 'Enregistrement impossible : $e', erreur: true);
        }
      }
      return;
    }
    final chemin = await recorder.stop();
    if (mounted) setState(() => _enregistre = false);
    if (chemin == null || !mounted) return;
    List<int> fichier;
    try {
      fichier = await File(chemin).readAsBytes();
    } catch (_) {
      afficherMessage(context, 'Lecture du vocal impossible', erreur: true);
      return;
    }
    if (fichier.isEmpty) return;
    await _repo.envoyer(
      expediteurId: widget.moi.id!,
      destinataireId: widget.autreId,
      contenu: base64Encode(fichier),
      type: 'vocal',
    );
    if (!mounted) return;
    setState(_recharger);
  }

  Future<void> _lireVocal(MessagePrive m) async {
    try {
      await _lecteur.play(BytesSource(base64Decode(m.contenu)));
    } catch (_) {
      if (mounted) {
        afficherMessage(context, 'Lecture impossible', erreur: true);
      }
    }
  }

  /// Petite barre emoji horizontale avec défilement (au-dessus du champ).
  void _ouvrirEmoji() {
    setState(() => _emojiVisible = !_emojiVisible);
  }

  Widget _barreEmoji() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) => InkWell(
          onTap: () => _saisie.text += _emojis[i],
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(_emojis[i], style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  void _appeler(bool video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppelScreen(nom: widget.autreNom, video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: widget.autreNom,
      actions: [
        IconButton(
          tooltip: 'Appel vocal',
          icon: const Icon(Icons.call_outlined),
          onPressed: () => _appeler(false),
        ),
        IconButton(
          tooltip: 'Appel vidéo',
          icon: const Icon(Icons.videocam_outlined),
          onPressed: () => _appeler(true),
        ),
      ],
      corps: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<MessagePrive>>(
              future: _messages,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final liste = snap.data!;
                if (liste.isEmpty) {
                  return const EtatVideModule(
                    icone: Icons.chat_bubble_outline,
                    titre: 'Nouvelle conversation',
                    message: '',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  itemBuilder: (context, i) {
                    final m = liste[liste.length - 1 - i];
                    final aMoi = m.expediteurId == widget.moi.id;
                    return Align(
                      alignment: aMoi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _bulle(m, aMoi),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_emojiVisible) _barreEmoji(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Emoji',
                  icon: Icon(
                      _emojiVisible
                          ? Icons.emoji_emotions
                          : Icons.emoji_emotions_outlined,
                      color: AppColors.teal),
                  onPressed: _ouvrirEmoji,
                ),
                IconButton(
                  tooltip: 'Photo',
                  icon: const Icon(Icons.add_a_photo_outlined,
                      color: AppColors.teal),
                  onPressed: _envoyerPhoto,
                ),
                IconButton(
                  tooltip: _enregistre ? 'Arrêter l’enregistrement' : 'Message vocal',
                  icon: Icon(
                      _enregistre ? Icons.stop_circle : Icons.mic_outlined,
                      color: _enregistre ? AppColors.danger : AppColors.teal),
                  onPressed: _envoyerVocal,
                ),
                Expanded(
                  child: TextField(
                    controller: _saisie,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _envoyer(),
                    decoration: decorationUi('Écrire un message…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Envoyer',
                  icon: const Icon(Icons.send, color: AppColors.teal),
                  onPressed: _envoyer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulle(MessagePrive m, bool aMoi) {
    final couleur = aMoi ? AppColors.teal : AppColors.tealLight;
    if (m.estImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          base64Decode(m.contenu),
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    if (m.estVocal) {
      return InkWell(
        onTap: () => _lireVocal(m),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill,
                  color: aMoi ? AppColors.white : AppColors.teal),
              const SizedBox(width: 8),
              Text('Vocal',
                  style: TextStyle(
                      color: aMoi ? AppColors.white : AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        m.contenu,
        style: TextStyle(
          color: aMoi ? AppColors.white : AppColors.navy,
          fontSize: 14,
        ),
      ),
    );
  }
}
