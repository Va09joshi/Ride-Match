import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MapShimmerLoader extends StatelessWidget {
  final bool showSearchBar;
  final bool showCenterButton;
  final int markerCount;

  const MapShimmerLoader({
    super.key,
    this.showSearchBar = true,
    this.showCenterButton = true,
    this.markerCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        /// 🌍 Fake Map Background
        _shimmerBox(
          child: Container(
            width: size.width,
            height: size.height,
            color: Colors.grey.shade300,
          ),
        ),

        /// 🔍 Search Bar Skeleton
        if (showSearchBar)
          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: _shimmerBox(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

        /// 🎯 Center Floating Button Skeleton
        if (showCenterButton)
          Positioned(
            bottom: 120,
            left: size.width * 0.25,
            right: size.width * 0.25,
            child: _shimmerBox(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),

        /// 📍 Map Marker Skeletons
        ...List.generate(markerCount, (index) {
          return Positioned(
            top: 180.0 + (index * 70),
            left: 40.0 + (index * 50),
            child: _shimmerBox(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 🔁 Reusable shimmer wrapper
  Widget _shimmerBox({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}
