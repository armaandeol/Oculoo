import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';

class Textfield extends StatelessWidget {
  final String lbl;
  final IconData? icon;
  final bool obscureText;
  final TextEditingController controller;

  const Textfield(
      {super.key,
      required this.lbl,
      required this.controller,
      this.icon,
      this.obscureText = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: TextInputType.text,
        autofocus: false,
        decoration: InputDecoration(
          suffixIcon: Icon(icon),
          hintText: lbl,
          hintStyle: TextStyle(color: AppColor.darkgrey),
          fillColor: AppColor.grey,
          filled: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(width: 10),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
