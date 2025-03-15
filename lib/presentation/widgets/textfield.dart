// textfield.dart
import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';

class Textfield extends StatelessWidget {
  final String lbl;
  final IconData? icon;
  final bool obscureText;
  final TextEditingController controller;
  final VoidCallback? onIconPressed;
  final String? Function(String?)? validator;

  const Textfield({
    super.key,
    required this.lbl,
    required this.controller,
    this.icon,
    this.obscureText = false,
    this.onIconPressed,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        decoration: InputDecoration(
          suffixIcon: icon != null
              ? IconButton(
                  icon: Icon(icon),
                  onPressed: onIconPressed,
                )
              : null,
          hintText: lbl,
          hintStyle: TextStyle(color: AppColor.darkgrey),
          fillColor: AppColor.grey,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1),
          ),
          errorStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
