import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';

class Textfield extends StatefulWidget {
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
  State<Textfield> createState() => _TextfieldState();
}

class _TextfieldState extends State<Textfield> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        keyboardType: TextInputType.text,
        autofocus: false,
        decoration: InputDecoration(
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : (widget.icon != null ? Icon(widget.icon) : null),
          hintText: widget.lbl,
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
