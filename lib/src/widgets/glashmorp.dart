import 'dart:ui';
import 'package:flutter/material.dart';

class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4), // Warna dasar transparan
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6), // Border putih tipis
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Latar Belakang Gradien Khas Apple/Minimalis
class LatarBelakangGradien extends StatelessWidget {
  const LatarBelakangGradien({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9), // Hijau sangat muda
            Color(0xFFF3E5F5), // Ungu sangat muda
            Color(0xFFE3F2FD), // Biru sangat muda
          ],
        ),
      ),
      child: child,
    );
  }
}