import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifiedDoc extends StatefulWidget {
  const VerifiedDoc({super.key});

  @override
  State<VerifiedDoc> createState() => _VerifiedDocState();
}

class _VerifiedDocState extends State<VerifiedDoc> {
  File? aadharFile;
  File? drivingFile;

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
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.black54,
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
                          horizontal: 12, vertical: 10),
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
                      onPressed: () {
                        print("Aadhar Submitted:");
                        print("Number: ${aadharController.text}");
                        print("File: ${aadharFile?.path}");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff113F67),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:  Text("Submit Aadhar",style: GoogleFonts.dmSans(color: Colors.white,fontWeight: FontWeight.bold),),
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
                          horizontal: 12, vertical: 10),
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
                      onPressed: () {
                        print("Driving License Submitted:");
                        print("Number: ${drivingController.text}");
                        print("File: ${drivingFile?.path}");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff113F67),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:  Text("Submit Driving License",style: GoogleFonts.dmSans(color: Colors.white,fontWeight: FontWeight.bold),),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      )
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
