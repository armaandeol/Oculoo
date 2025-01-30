import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class LogMedicinePage extends StatefulWidget {
  @override
  _LogMedicinePageState createState() => _LogMedicinePageState();
}

class _LogMedicinePageState extends State<LogMedicinePage> {
  File? _image;
  final picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<String> uploadImage(File imageFile) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('images/${DateTime.now().toIso8601String()}');

    final uploadTask = storageRef.putFile(imageFile);

    final snapshot = await uploadTask.whenComplete(() => null);

    final imageUrl = await snapshot.ref.getDownloadURL();

    return imageUrl;
  }

  Future<void> notifyFlaskServer(String imageUrl) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final url = Uri.parse('http://10.55.134.220:5000/process_image'); // Replace with your Flask server URL
    final String uid = user?.uid ?? '';
    
    if (uid.isEmpty) {
      print('UID is missing');
      return;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: '{"imageUrl": "$imageUrl", "uid": "$uid"}',
    );

    if (response.statusCode == 200) {
      print('Flask server notified successfully.');
    } else {
      print('Failed to notify Flask server. Status: ${response.statusCode}');
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      print('No image selected');
      return;
    }

    try {
      String imageUrl = await uploadImage(_image!);
      print('Image uploaded successfully: $imageUrl');

      await _firestore.collection('Medications').add({
        'image_url': imageUrl,
        'uploaded_at': FieldValue.serverTimestamp(),
      });

      await notifyFlaskServer(imageUrl);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Image has been uploaded successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                Navigator.pop(context); // Optionally navigate back or clear the form
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Upload Error"),
          content: const Text("Failed to upload image. Please try again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      print("Error uploading image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNavBarCustome(),
      appBar: AppBar(
        title: Text('Log Medicine'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? Text('No image selected.')
                : Image.file(_image!),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadImage,
              child: Text('Upload Image'),
            ),
          ],
        ),
      ),
    );
  }
}
