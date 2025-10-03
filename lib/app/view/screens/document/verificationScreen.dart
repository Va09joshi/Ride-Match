import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Verificationscreen extends StatefulWidget {
  const Verificationscreen({super.key});

  @override
  State<Verificationscreen> createState() => _VerificationscreenState();
}

class _VerificationscreenState extends State<Verificationscreen> {
  // --- Style Definitions from previous screens ---
  // Using the core RideMatch colors (Blue and Orange)
  final Color primaryBlue = const Color(0xFF192182);
  final Color primaryOrange = const Color(0xFFE87D2A);

  // Custom colors are removed since we are using logo colors
  // final Color cardColor = const Color(0xFFF7F7F7);
  // final Color appbarPurple = const Color(0xFF673AB7);
  // final Color buttonPurple = const Color(0xFF9C27B0);

  // State to track if documents have been uploaded (dummy implementation)
  bool aadhaarFrontUploaded = false;
  bool aadhaarBackUploaded = false;
  bool licenseFrontUploaded = false;
  bool licenseBackUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar is removed as requested
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header (replaces AppBar content)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  "RideMatch - Document Submission",
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: primaryBlue, // Using primary blue for the title
                  ),
                ),
              ),

              // Welcome Message
              Center(
                child: Text(
                  "Welcome, [User Name]!",
                  style: GoogleFonts.lato(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "To ensure a safe and verified community",
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),

              Center(
                child: Text(
                  "please submit the following documents:",
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- 1. Aadhaar Card Section ---
              _buildDocumentSection(
                number: 1,
                title: "Aadhaar Card (Mandatory for all users)",
                description: "Your Aadhaar card is required to verify your identity.",
                slots: [
                  DocumentSlot(
                    title: "Front Side:",
                    isUploaded: aadhaarFrontUploaded,
                    onUpload: () => setState(() => aadhaarFrontUploaded = !aadhaarFrontUploaded),
                    primaryColor: primaryBlue,
                  ),
                  DocumentSlot(
                    title: "Back Side:",
                    isUploaded: aadhaarBackUploaded,
                    onUpload: () => setState(() => aadhaarBackUploaded = !aadhaarBackUploaded),
                    primaryColor: primaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // --- 2. Driving License Section ---
              _buildDocumentSection(
                number: 2,
                title: "Driving License (Mandatory for Drivers)",
                description: "If you plan to offer rides, please submit your license.",
                isLocked: true,
                slots: [
                  DocumentSlot(
                    title: "Front Side:",
                    isUploaded: licenseFrontUploaded,
                    onUpload: () => setState(() => licenseFrontUploaded = !licenseFrontUploaded),
                    primaryColor: primaryBlue,
                  ),
                  DocumentSlot(
                    title: "Back Side:",
                    isUploaded: licenseBackUploaded,
                    onUpload: () => setState(() => licenseBackUploaded = !licenseBackUploaded),
                    primaryColor: primaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- Submit Button (using Blue/Orange Gradient) ---
              GestureDetector(
                onTap: () {
                  debugPrint("Documents Submitted!");
                },
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient( // Use gradient for a dynamic look
                      colors: [primaryBlue, primaryOrange],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "SUBMIT DOCUMENTS",
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- Important Notes ---
              Text(
                "Important Notes:",
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _buildNoteBullet("Please ensure documents are clear and readable."),
              _buildNoteBullet("All data is encrypted and kept confidential."),
              _buildNoteBullet("Verification may take up to 24 hours."),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection({
    required int number,
    required String title,
    required String description,
    required List<DocumentSlot> slots,
    bool isLocked = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$number. ",
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            if (isLocked)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 24),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 18.0),
          child: Text(
            description,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: slots,
        ),
      ],
    );
  }

  Widget _buildNoteBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("•  ", style: TextStyle(fontSize: 16, color: Colors.black87)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Widget for the upload slots
class DocumentSlot extends StatelessWidget {
  final String title;
  final bool isUploaded;
  final VoidCallback onUpload;
  final Color primaryColor; // Added to allow color customization

  const DocumentSlot({
    required this.title,
    required this.isUploaded,
    required this.onUpload,
    required this.primaryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            // Upload Button
            GestureDetector(
              onTap: onUpload,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor, // Using the new primary color (blue)
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    isUploaded ? "Change File" : "Upload File",
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Upload Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUploaded ? Icons.check_circle : Icons.camera_alt_outlined,
                  color: isUploaded ? Colors.green : Colors.grey.shade400,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  isUploaded ? "Image uploaded" : "No image uploaded",
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: isUploaded ? Colors.green : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
