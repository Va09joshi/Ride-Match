import 'dart:io';
import 'package:flutter/material.dart';

class ProfileImage extends StatelessWidget {
  final File? localImage; // Image just picked by user
  final String? imageUrl; // Image URL from backend
  final double radius;
  final VoidCallback? onTap;

  const ProfileImage({
    super.key,
    this.localImage,
    this.imageUrl,
    this.radius = 55,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            backgroundImage: localImage != null
                ? FileImage(localImage!)
                : ((imageUrl != null && imageUrl!.isNotEmpty)
                ? NetworkImage(imageUrl!)
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
