import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/theme/app_colors.dart';

/// Appel vocal / vidéo (comme SyrWriteHub) : connexion locale en boucle
/// (l'utilisateur s'appelle lui-même, sans serveur de signalisation).
/// Écran de démonstration de l'interface d'appel.
class AppelScreen extends StatefulWidget {
  final String nom;
  final bool video;

  const AppelScreen({super.key, required this.nom, required this.video});

  @override
  State<AppelScreen> createState() => _AppelScreenState();
}

class _AppelScreenState extends State<AppelScreen> {
  RTCVideoRenderer _local = RTCVideoRenderer();
  RTCPeerConnection? _connexion;
  MediaStream? _flux;
  bool _micro = true;
  bool _camera = true;
  int _secondes = 0;
  Timer? _chronometre;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    await _local.initialize();
    _connexion = await createPeerConnection({});
    _flux = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      if (widget.video) 'video': {'facingMode': 'user'},
    });
    for (final piste in _flux!.getTracks()) {
      await _connexion!.addStream(_flux!);
    }
    _connexion!.onAddStream?.call(_flux!);
    final offre = await _connexion!.createOffer({});
    await _connexion!.setLocalDescription(offre);
    await _connexion!.setRemoteDescription(offre);
    if (mounted) setState(() {});
    _chronometre = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondes++);
    });
  }

  String get _duree {
    final m = (_secondes ~/ 60).toString().padLeft(2, '0');
    final s = (_secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _chronometre?.cancel();
    _flux?.getTracks().forEach((t) => t.stop());
    _connexion?.close();
    _local.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.teal,
              child: Text(
                widget.nom.split(' ').first.isEmpty
                    ? '?'
                    : widget.nom.split(' ').first[0],
                style: const TextStyle(color: AppColors.white, fontSize: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.nom,
                style: const TextStyle(
                    color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              widget.video ? 'Appel vidéo · $_duree' : 'Appel vocal · $_duree',
              style: const TextStyle(color: AppColors.white, fontSize: 14),
            ),
            if (widget.video) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(_local, mirror: true),
                ),
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'micro',
                  backgroundColor:
                      _micro ? AppColors.white : AppColors.danger,
                  onPressed: () {
                    _flux?.getAudioTracks().forEach((t) => t.enabled = !_micro);
                    setState(() => _micro = !_micro);
                  },
                  child: Icon(_micro ? Icons.mic : Icons.mic_off,
                      color: _micro ? AppColors.navy : AppColors.white),
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  heroTag: 'fin',
                  backgroundColor: AppColors.danger,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.call_end, color: AppColors.white),
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  heroTag: 'cam',
                  backgroundColor:
                      _camera ? AppColors.white : AppColors.danger,
                  onPressed: () {
                    _flux?.getVideoTracks().forEach((t) => t.enabled = !_camera);
                    setState(() => _camera = !_camera);
                  },
                  child: Icon(_camera ? Icons.videocam : Icons.videocam_off,
                      color: _camera ? AppColors.navy : AppColors.white),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
