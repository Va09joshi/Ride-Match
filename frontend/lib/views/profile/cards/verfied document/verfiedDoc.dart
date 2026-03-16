import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifiedDoc extends StatefulWidget {
  const VerifiedDoc({super.key});

  @override
  State<VerifiedDoc> createState() => _VerifiedDocState();
}

class _VerifiedDocState extends State<VerifiedDoc> {
  File? aadharFile;
  File? drivingFile;
  bool _aadharUploading = false;
  bool _drivingUploading = false;
  String _verificationStatus = 'not_submitted';

  final TextEditingController aadharController = TextEditingController();
  final TextEditingController drivingController = TextEditingController();

  Future<void> pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      type: FileType.custom,
    );

    if (result != null) {
      setState(() {
        if (type == "aadhar") {
          aadharFile = File(result.files.single.path!);
        } else {
          drivingFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _uploadDocument(String type) async {
    final isAadhar = type == 'aadhar';
    final number = isAadhar
        ? aadharController.text.trim()
        : drivingController.text.trim();
    final file = isAadhar ? aadharFile : drivingFile;

    if (file == null) {
      _snack('Please choose a file first.', error: true);
      return;
    }
    if (number.isEmpty) {
      _snack('Please enter the document number.', error: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      _snack('Please login again.', error: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      if (isAadhar) {
        _aadharUploading = true;
      } else {
        _drivingUploading = true;
      }
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        AppApi.uri(AppEndpoints.profileUploadVerification),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['type'] = isAadhar ? 'aadhar' : 'driving_license';
      request.fields['number'] = number;
      request.files.add(
        await http.MultipartFile.fromPath('document', file.path),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        _snack('Document uploaded successfully. Verification pending review.');
        if (mounted) {
          setState(() {
            _verificationStatus = 'pending';
          });
        }
      } else {
        _snack('Upload failed: $body', error: true);
      }
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    } finally {
      if (!mounted) return;
      setState(() {
        if (isAadhar) {
          _aadharUploading = false;
        } else {
          _drivingUploading = false;
        }
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.93),
      appBar: AppBar(
        backgroundColor: Color(0xff113F67),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Document Verification",
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              "Required Documents",
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              "Please upload the following documents to complete your verification",
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              "Status: ${_verificationStatus.replaceAll('_', ' ').toUpperCase()}",
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _verificationStatus == 'verified'
                    ? Colors.green
                    : (_verificationStatus == 'pending'
                          ? Colors.orange
                          : Colors.black54),
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            // AADHAR CARD
            docTile(
              icon: Icons.account_balance_rounded,
              title: "Aadhar Card",
              status: aadharFile != null ? "Uploaded" : "Upload Now",
              statusColor: aadharFile != null ? Colors.green : Colors.blue,
              onTap: () => pickFile("aadhar"),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "Aadhar Number",
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: aadharController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Enter Aadhar Number",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // SUBMIT ONLY AADHAR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _aadharUploading
                          ? null
                          : () => _uploadDocument('aadhar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff113F67),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _aadharUploading ? 'Uploading...' : 'Submit Aadhar',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // DRIVING LICENSE
            docTile(
              icon: Icons.directions_car_rounded,
              title: "Driving License",
              status: drivingFile != null ? "Uploaded" : "Upload Now",
              statusColor: drivingFile != null ? Colors.green : Colors.blue,
              onTap: () => pickFile("driving"),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "License Number",
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: drivingController,
                    decoration: InputDecoration(
                      hintText: "Enter License Number",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // SUBMIT ONLY DRIVING LICENSE
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _drivingUploading
                          ? null
                          : () => _uploadDocument('driving_license'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff113F67),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _drivingUploading
                            ? 'Uploading...'
                            : 'Submit Driving License',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // SUBMIT ALL
          ],
        ),
      ),
    );
  }

  // DOCUMENT TILE WIDGET
  Widget docTile({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
    Widget? child,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade200,
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          subtitle,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        status,
                        style: GoogleFonts.dmSans(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        status == "Upload Now"
                            ? Icons.upload_rounded
                            : Icons.check_circle_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (child != null) child,
        ],
      ),
    );
  }
}
