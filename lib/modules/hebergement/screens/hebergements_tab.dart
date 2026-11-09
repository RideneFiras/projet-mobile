import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hebergement_repository.dart';
import '../models/hebergement.dart';
import 'hebergement_form_screen.dart';
import 'sejour_form_screen.dart';

/// Liste des établissements, en deux modes :
/// - [gestion] = true (administrateur) : ajout, modification, suppression du catalogue ;
/// - [gestion] = false (voyageur) : choisir un établissement et réserver un séjour.
class HebergementsTab extends StatefulWidget {
  final bool gestion;

  const HebergementsTab({super.key, this.gestion = false});

  @override
  State<HebergementsTab> createState() => _HebergementsTabState();
}

class _HebergementsTabState extends State<HebergementsTab> {
  final _repo = HebergementRepository();
  late Future<List<Hebergement>> _futur;

  @override
  void initState() {
    super.initState();
    _futur = _repo.hebergements();
  }

  Future<void> _recharger() async {
    setState(() {
      _futur = _repo.hebergements();
    });
    await _futur;
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const HebergementFormScreen()),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _modifier(Hebergement h) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HebergementFormScreen(hebergement: h)),
    );
    if (ok == true && mounted) await _recharger();
  }

  Future<void> _reserver(Hebergement h) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SejourFormScreen(hebergementId: h.id)),
    );
    if (ok == true && mounted) afficherMessage(context, 'Séjour enregistré');
  }

  Future<void> _supprimer(Hebergement h) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ${h.nom} ?',
      message: 'Les séjours réservés dans cet établissement seront supprimés aussi.',
    );
    if (!ok || !mounted) return;
    await _repo.supprimerHebergement(h.id!);
    if (!mounted) return;
    afficherMessage(context, 'Établissement supprimé');
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Hebergement>>(
      future: _futur,
      builder: (context, snap) {
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
        final liste = snap.data!;
        return RefreshIndicator(
          onRefresh: _recharger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              EnteteSection(
                titre: widget.gestion
                    ? 'Établissements (${liste.length})'
                    : 'Où séjourner (${liste.length})',
                action: widget.gestion
                    ? TextButton.icon(
                        onPressed: _ajouter,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                (widget.gestion
                    ? EtatVideModule(
                        icone: Icons.bed_outlined,
                        titre: 'Aucun établissement',
                        message: 'Ajoutez les hôtels et logements proposés.',
                        libelleAction: 'Ajouter un établissement',
                        onAction: _ajouter,
                      )
                    : const EtatVideModule(
                        icone: Icons.bed_outlined,
                        titre: 'Aucun établissement',
                        message: "Le catalogue n'est pas encore rempli.",
                      ))
              else
                GrilleAdaptative(
                  largeurMin: 320,
                  enfants: [for (final h in liste) _carte(h)],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _carte(Hebergement h) {
    return CarteModule(
      accent: AppColors.teal,
      onTap: widget.gestion ? () => _modifier(h) : () => _reserver(h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(h.nom,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Pastille(libelle: h.type, valeur: 'actif'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(h.adresse,
                    style: const TextStyle(color: AppColors.grey, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${Montants.affiche(h.prixParNuit)} / nuit',
                  style: const TextStyle(
                      color: AppColors.teal, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.gestion)
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _supprimer(h),
                )
              else
                TextButton.icon(
                  onPressed: () => _reserver(h),
                  icon: const Icon(Icons.event_available, size: 20),
                  label: const Text('Réserver',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.teal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
