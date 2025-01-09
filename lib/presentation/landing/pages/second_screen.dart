import 'package:flutter/material.dart';
import 'package:oculoo02/core/configs/assets/app_images.dart';

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            width: 300,
            height: 200,
            child: Image.asset(AppImages.land2, fit: BoxFit.cover),
          ),
        ),
        Text(
          "Seamless Updates",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 255, 199, 59)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
          child: Text(
            "Get real-time updates on their well-being",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                // fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 19, 54, 33)),
          ),
        ),
      ],
    );
  }
}
