import 'package:flutter/material.dart';

/// Reusable InfoCard Widget
class InfoCard extends StatelessWidget {
  final String name;
  final double rating; // e.g. 4.5
  final String time; // e.g. "25 mins"
  final String distance; // e.g. "2.4 km"
  final String address;
  final String? profileImageUrl; // optional
  final VoidCallback? onTap;

  const InfoCard({
    Key? key,
    required this.name,
    required this.rating,
    required this.time,
    required this.distance,
    required this.address,
    this.profileImageUrl, // optional
    this.onTap,
  }) : super(key: key);

  // Build stars for rating
  List<Widget> _buildRatingStars(double rating) {
    final List<Widget> stars = [];
    int full = rating.floor();
    bool hasHalf = (rating - full) >= 0.5;

    for (int i = 0; i < full; i++) {
      stars.add(const Icon(Icons.star, size: 14, color: Colors.amber));
    }
    if (hasHalf) {
      stars.add(const Icon(Icons.star_half, size: 14, color: Colors.amber));
    }
    while (stars.length < 5) {
      stars.add(const Icon(Icons.star_border, size: 14, color: Colors.amber));
    }
    return stars;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ✅ Profile is optional
              CircleAvatar(
                radius: 30,
                backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                child: profileImageUrl == null
                    ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                )
                    : null,
                backgroundColor: profileImageUrl == null
                    ? Colors.blueGrey
                    : Colors.transparent,
              ),

              const SizedBox(width: 12),

              // Info section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + rating row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            ..._buildRatingStars(rating),
                            const SizedBox(width: 6),
                            Text(rating.toStringAsFixed(1)),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Address
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Time + distance
                    Row(
                      children: [
                        _SmallInfoChip(icon: Icons.access_time, text: time),
                        const SizedBox(width: 8),
                        _SmallInfoChip(icon: Icons.location_on, text: distance),
                        const Spacer(),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small reusable chip inside card
class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SmallInfoChip({Key? key, required this.icon, required this.text})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Function-style builder (shortcut)
Widget infoCard({
  required String name,
  required double rating,
  required String time,
  required String distance,
  required String address,
  String? profileImageUrl,
  VoidCallback? onTap,
}) {
  return InfoCard(
    name: name,
    rating: rating,
    time: time,
    distance: distance,
    address: address,
    profileImageUrl: profileImageUrl,
    onTap: onTap,
  );
}
