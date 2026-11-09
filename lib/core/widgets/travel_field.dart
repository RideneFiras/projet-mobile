import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Champ du UI Kit : carte blanche arrondie, icône à gauche, petit libellé
/// AU-DESSUS de la saisie, à l'intérieur de la carte.
/// [afficherOeil] : bouton « voir le mot de passe » (absent sur « Confirmer »).
/// Désactivé (enabled: false) : fond gris, texte grisé, comme la maquette.
class TravelField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? icone;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool motDePasse;
  final bool afficherOeil;
  final bool enabled;
  final TextInputAction? textInputAction;

  const TravelField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icone,
    this.validator,
    this.keyboardType,
    this.motDePasse = false,
    this.afficherOeil = true,
    this.enabled = true,
    this.textInputAction,
  });

  @override
  State<TravelField> createState() => _TravelFieldState();
}

class _TravelFieldState extends State<TravelField> {
  final FocusNode _focus = FocusNode();
  bool _masque = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grise = !widget.enabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: grise ? AppColors.disabled : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focus.hasFocus ? AppColors.teal : AppColors.border,
          width: _focus.hasFocus ? 1.6 : 1,
        ),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        validator: widget.validator,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        obscureText: widget.motDePasse && _masque,
        style: TextStyle(
          fontSize: 16,
          color: grise ? AppColors.grey : AppColors.navy,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: widget.label,
          hintText: widget.hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          floatingLabelStyle: const TextStyle(
              color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w600),
          labelStyle: const TextStyle(
              color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(color: Color(0xFF8A97A5)),
          errorStyle: const TextStyle(color: AppColors.danger),
          contentPadding:
              EdgeInsets.fromLTRB(widget.icone == null ? 16 : 0, 10, 12, 12),
          prefixIcon: widget.icone == null
              ? null
              : Icon(widget.icone, color: AppColors.grey),
          suffixIcon: widget.motDePasse && widget.afficherOeil
              ? IconButton(
                  icon: Icon(_masque
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  color: AppColors.grey,
                  onPressed: () => setState(() => _masque = !_masque),
                )
              : null,
        ),
      ),
    );
  }
}
