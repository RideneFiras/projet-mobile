import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../notification.dart';
import '../notification_repository.dart';
import '../utilisateur.dart';

/// Notifications du fil : « X a commenté/aimé/voté ton post ».
/// Ouvertes depuis la cloche de l'onglet Actualités ; à l'ouverture,
/// toutes les notifications sont marquées comme lues.
class NotificationsScreen extends StatefulWidget {
  final Utilisateur utilisateur;

  const NotificationsScreen({super.key, required this.utilisateur});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationFil>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = NotificationRepository().lister(widget.utilisateur.id!);
    // Marquées lues à l'ouverture (la pastille reflète le nouvel état).
    NotificationRepository().toutMarquerLu(widget.utilisateur.id!);
  }

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Notifications',
      corps: FutureBuilder<List<NotificationFil>>(
        future: _notifications,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = snap.data!;
          if (liste.isEmpty) {
            return const EtatVideModule(
              icone: Icons.notifications_outlined,
              titre: 'Aucune notification',
              message: 'Quand quelqu’un réagit à vos posts, vous le verrez ici.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final n = liste[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CarteModule(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.tealLight, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications,
                            color: AppColors.teal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.texte as String,
                                style: const TextStyle(fontSize: 14)),
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
