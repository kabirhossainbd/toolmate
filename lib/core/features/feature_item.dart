import 'package:flutter/material.dart';

/// Immutable catalog entry describing a home / tools feature tile.
class FeatureItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String category; // Tools | Media | Storage | System

  const FeatureItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    required this.category,
  });
}
