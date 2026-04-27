import 'dart:math';
import 'package:flutter/material.dart';

class LetterFragments {
  static final Map<String, List<String>> _fragmentMap = {
    'A': ['/', '-', '\\', '|', '/'],
    'B': ['|', ')', '-', ')', '|'],
    'C': ['(', '-', '('],
    'D': ['|', '\\', '/', '|'],
    'E': ['|', '-', '|', '-', '|'],
    'F': ['|', '-', '|', '-'],
    'G': ['(', '-', '-', '|'],
    'H': ['|', '|', '-', '|', '|'],
    'I': ['|', '|', '|'],
    'J': ['|', '|', '/'],
    'K': ['|', '/', '-', '\\', '|'],
    'L': ['|', '|', '_'],
    'M': ['|', '\\', '/', '|', '|'],
    'N': ['|', '\\', '|', '|'],
    'O': ['(', '-', ')'],
    'P': ['|', ')', '-', '|'],
    'Q': ['(', '-', ')', '\\'],
    'R': ['|', ')', '-', '\\', '|'],
    'S': ['_', ')', '(', '_'],
    'T': ['-', '|', '|'],
    'U': ['|', '|', '_'],
    'V': ['\\', '/', '\\', '/'],
    'W': ['\\', '/', '\\', '/', '\\', '/'],
    'X': ['\\', '/', '\\', '/'],
    'Y': ['\\', '/', '|'],
    'Z': ['-', '/', '-'],
  };

  static List<String> getFragments(String letter) {
    return _fragmentMap[letter.toUpperCase()] ?? ['-', '|'];
  }

  static String getRandomFragment(List<String> exclude, {List<String>? preferred}) {
    final allFragments = ['/', '\\', '|', '-', '_', '(', ')', '<', '>'];
    final available = preferred?.where((f) => !exclude.contains(f)).toList() ?? 
                      allFragments.where((f) => !exclude.contains(f)).toList();
    
    if (available.isEmpty) return allFragments[Random().nextInt(allFragments.length)];
    return available[Random().nextInt(available.length)];
  }

  static Color getFragmentColor(String fragment) {
    switch (fragment) {
      case '/': return const Color(0xFFFF6B6B);
      case '\\': return const Color(0xFF4ECDC4);
      case '|': return const Color(0xFF45B7D1);
      case '-': return const Color(0xFF96CEB4);
      case '_': return const Color(0xFFFFEAA7);
      case '(': return const Color(0xFFDDA0DD);
      case ')': return const Color(0xFF98D8C8);
      case '<': return const Color(0xFFF7DC6F);
      case '>': return const Color(0xFFBB8FCE);
      default: return const Color(0xFF85C1E9);
    }
  }

  static List<String> getTargetSequence(String target) {
    final List<String> sequence = [];
    for (var char in target.toUpperCase().split('')) {
      final fragments = getFragments(char);
      sequence.addAll(fragments);
      sequence.add('*'); // Letter separator
    }
    if (sequence.isNotEmpty) sequence.removeLast();
    return sequence;
  }
}
