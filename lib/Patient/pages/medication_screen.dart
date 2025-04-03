import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/medication_service.dart';

class MedicationScreen extends StatefulWidget {
  @override
  _MedicationScreenState createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  File? _image;
  final picker = ImagePicker();
  final TextEditingController _medicationNameController =
      TextEditingController();
  final MedicationService _medicationService = MedicationService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showSuccess = false;

  @override
  void dispose() {
    _medicationNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
      );

      setState(() {
        if (pickedFile != null) {
          _image = File(pickedFile.path);
        }
      });
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _errorMessage = 'Failed to pick image. Please try again.';
      });
    }
  }

  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('medication_images/${DateTime.now().toIso8601String()}');

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _errorMessage = 'Failed to upload image. Please try again.';
      });
      return null;
    }
  }

  Future<void> _logMedication() async {
    final medicationName = _medicationNameController.text.trim();
    if (medicationName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a medication name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImageToStorage(_image!);
        if (imageUrl == null) {
          // Error already set in _uploadImageToStorage
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      await _medicationService.logMedication(
        medicationName: medicationName,
        taken: true,
        imageUrl: imageUrl,
      );

      // Clear the form and show success message
      _medicationNameController.clear();
      setState(() {
        _image = null;
        _isLoading = false;
        _showSuccess = true;
      });

      // Hide success message after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSuccess = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error logging medication: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNavBarCustome(),
      appBar: AppBar(
        title: const Text('Log Medication'),
        backgroundColor: Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red.shade900),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),

              // Success message
              if (_showSuccess)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Medication logged successfully! Your guardian will be notified.',
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              TextField(
                controller: _medicationNameController,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter the name of your medication',
                  prefixIcon: Icon(Icons.medical_services),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Take a photo of your medication',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showImageSourceMenu,
                icon: Icon(Icons.camera_alt),
                label: Text('Add Photo'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 16),

              if (_image != null) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.file(
                          _image!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      ButtonBar(
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.refresh),
                            label: Text('Change'),
                            onPressed: _showImageSourceMenu,
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.delete, color: Colors.red),
                            label: Text('Remove',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => setState(() => _image = null),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: _isLoading ? null : _logMedication,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Logging Medication...'),
                        ],
                      )
                    : Text('Submit Medication Log'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  textStyle:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
