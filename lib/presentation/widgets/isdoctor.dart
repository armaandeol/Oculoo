import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';




class IsGuardian extends StatefulWidget {
  final String Guardian;
  const IsGuardian({super.key,this.Guardian = "Become a Guardian"});

  @override
  State<IsGuardian> createState() => _IsGuardianState();
}


class _IsGuardianState extends State<IsGuardian> {
  bool IsGuardian = false;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(widget.Guardian, style: TextStyle(color: AppColor.secondary)),
        Switch(value: IsGuardian,
        inactiveTrackColor: AppColor.primary,
        activeColor: AppColor.secondary, 
        onChanged: (value){setState(() {
          IsGuardian = value;
        });},)
      ],
    );
  }
}