import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';

class IsGuardian extends StatefulWidget {
  final String guardian; // Lowercase parameter name
  final ValueChanged<bool>? onChanged;
  const IsGuardian({
    super.key,
    this.guardian = "Become a Guardian",
    this.onChanged,
  });

  @override
  State<IsGuardian> createState() => _IsGuardianState();
}

class _IsGuardianState extends State<IsGuardian> {
  bool _isGuardian = false; // Lowercase variable name

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(widget.guardian, style: TextStyle(color: AppColor.secondary)),
        Switch(
          value: _isGuardian,
          inactiveTrackColor: AppColor.primary,
          activeColor: AppColor.secondary,
          onChanged: (value) {
            setState(() {
              _isGuardian = value;
            });
            widget.onChanged?.call(value); // Notify parent
          },
        )
      ],
    );
  }
}
