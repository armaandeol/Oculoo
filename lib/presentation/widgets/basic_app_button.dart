import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';


class BasicAppButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const BasicAppButton({Key? key, required this.onPressed, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.darkgrey,
      ),
      child: child,
    );
  }
} 