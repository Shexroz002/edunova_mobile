import 'package:flutter/material.dart';

/// Icon and color for a subject, chosen by its name.
///
/// The backend `icon` field is usually empty, so the app decides.
class SubjectStyle {
  const SubjectStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  /// Style for a subject name such as "Matematika" or "Fizika".
  factory SubjectStyle.of(String? subject) {
    final name = (subject ?? '').toLowerCase();
    if (name.contains('matem') || name.contains('algebra') || name.contains('geometr')) {
      return const SubjectStyle(Icons.calculate_outlined, Color(0xFF818CF8));
    }
    if (name.contains('fizik')) {
      return const SubjectStyle(Icons.science_outlined, Color(0xFF38BDF8));
    }
    if (name.contains('kimyo')) {
      return const SubjectStyle(Icons.biotech_outlined, Color(0xFF34D399));
    }
    if (name.contains('biolog')) return const SubjectStyle(Icons.eco_outlined, Color(0xFF22C55E));
    if (name.contains('ingliz') || name.contains('english') || name.contains('til')) {
      return const SubjectStyle(Icons.translate_rounded, Color(0xFFF472B6));
    }
    if (name.contains('tarix')) {
      return const SubjectStyle(Icons.history_edu_outlined, Color(0xFFFBBF24));
    }
    if (name.contains('geograf')) {
      return const SubjectStyle(Icons.public_outlined, Color(0xFF2DD4BF));
    }
    if (name.contains('informat')) {
      return const SubjectStyle(Icons.computer_outlined, Color(0xFFA78BFA));
    }
    return const SubjectStyle(Icons.menu_book_outlined, Color(0xFF94A3B8));
  }
}
