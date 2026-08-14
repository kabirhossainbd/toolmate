import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Immutable catalog entry describing a home / tools feature tile.
class FeatureItem {
  final String id;
  final String title;
  final String subtitle;
  final FaIconData icon;
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
