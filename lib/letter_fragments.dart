import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Segment types ──────────────────────────────────────────────────────────
enum SegType { line, arc }

class Seg {
  final SegType type;
  final Offset? a, b;
  final Rect? rect;
  final double? start, sweep;

  const Seg.line(this.a, this.b)
      : type = SegType.line,
        rect = null,
        start = null,
        sweep = null;

  const Seg.arc(this.rect, this.start, this.sweep)
      : type = SegType.arc,
        a = null,
        b = null;

  void draw(Canvas canvas, Size size, Paint paint) {
    if (type == SegType.line) {
      canvas.drawLine(
        Offset(a!.dx * size.width, a!.dy * size.height),
        Offset(b!.dx * size.width, b!.dy * size.height),
        paint,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(
          rect!.left * size.width,
          rect!.top * size.height,
          rect!.width * size.width,
          rect!.height * size.height,
        ),
        start!,
        sweep!,
        false,
        paint,
      );
    }
  }
}

// ─── Letter colors (candy-crush vivid palette) ───────────────────────────────
const Map<String, Color> kLetterColors = {
  'A': Color(0xFFE53935),
  'B': Color(0xFF1565C0),
  'C': Color(0xFFFF8F00),
  'D': Color(0xFF6A1B9A),
  'E': Color(0xFF00897B),
  'F': Color(0xFFF4511E),
  'G': Color(0xFF2E7D32),
  'H': Color(0xFFAD1457),
  'I': Color(0xFF0097A7),
  'J': Color(0xFF558B2F),
  'K': Color(0xFFC62828),
  'L': Color(0xFF0277BD),
  'M': Color(0xFFEF6C00),
  'N': Color(0xFF00838F),
  'O': Color(0xFF4527A0),
  'P': Color(0xFF283593),
  'Q': Color(0xFFF57F17),
  'R': Color(0xFF880E4F),
  'S': Color(0xFF1B5E20),
  'T': Color(0xFF4A148C),
  'U': Color(0xFF006064),
  'V': Color(0xFFE65100),
  'W': Color(0xFF37474F),
  'X': Color(0xFF33691E),
  'Y': Color(0xFF827717),
  'Z': Color(0xFF4E342E),
};

// ─── Piece definitions per letter (normalized 0-1 coords) ────────────────────
// Each letter = list of pieces; each piece = list of Segs.
// Together all pieces form the letter shape.
const Map<String, List<List<Seg>>> kPieces = {
  'A': [
    [Seg.line(Offset(0.50, 0.08), Offset(0.10, 0.92))], // left leg
    [Seg.line(Offset(0.22, 0.54), Offset(0.78, 0.54))], // crossbar
    [Seg.line(Offset(0.50, 0.08), Offset(0.90, 0.92))], // right leg
  ],
  'B': [
    [Seg.line(Offset(0.25, 0.10), Offset(0.25, 0.90))], // vertical
    [Seg.arc(Rect.fromLTWH(0.25, 0.10, 0.52, 0.40), -math.pi / 2, math.pi)], // top bump
    [Seg.arc(Rect.fromLTWH(0.25, 0.50, 0.56, 0.40), -math.pi / 2, math.pi)], // bottom bump
  ],
  'C': [
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), math.pi * 0.40, math.pi * 0.80)],
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), -math.pi * 0.20, math.pi * 0.80)],
  ],
  'D': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.22, 0.90))],
    [Seg.arc(Rect.fromLTWH(0.22, 0.10, 0.62, 0.80), -math.pi / 2, math.pi)],
  ],
  'E': [
    [Seg.line(Offset(0.20, 0.10), Offset(0.20, 0.90))],
    [Seg.line(Offset(0.20, 0.10), Offset(0.84, 0.10))],
    [Seg.line(Offset(0.20, 0.50), Offset(0.72, 0.50))],
    [Seg.line(Offset(0.20, 0.90), Offset(0.84, 0.90))],
  ],
  'F': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.22, 0.90))],
    [Seg.line(Offset(0.22, 0.10), Offset(0.84, 0.10))],
    [Seg.line(Offset(0.22, 0.50), Offset(0.72, 0.50))],
  ],
  'G': [
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), math.pi * 0.40, math.pi * 0.80)],
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), -math.pi * 0.25, math.pi * 0.65)],
    [Seg.line(Offset(0.90, 0.50), Offset(0.54, 0.50))],
  ],
  'H': [
    [Seg.line(Offset(0.15, 0.10), Offset(0.15, 0.90))],
    [Seg.line(Offset(0.15, 0.50), Offset(0.85, 0.50))],
    [Seg.line(Offset(0.85, 0.10), Offset(0.85, 0.90))],
  ],
  'I': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.78, 0.10))],
    [Seg.line(Offset(0.50, 0.10), Offset(0.50, 0.90))],
    [Seg.line(Offset(0.22, 0.90), Offset(0.78, 0.90))],
  ],
  'J': [
    [
      Seg.line(Offset(0.20, 0.10), Offset(0.80, 0.10)),
      Seg.line(Offset(0.64, 0.10), Offset(0.64, 0.68)),
    ],
    [Seg.arc(Rect.fromLTWH(0.16, 0.50, 0.48, 0.40), 0, math.pi)],
  ],
  'K': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.22, 0.90))],
    [Seg.line(Offset(0.22, 0.50), Offset(0.84, 0.10))],
    [Seg.line(Offset(0.22, 0.50), Offset(0.84, 0.90))],
  ],
  'L': [
    [Seg.line(Offset(0.25, 0.10), Offset(0.25, 0.90))],
    [Seg.line(Offset(0.25, 0.90), Offset(0.82, 0.90))],
  ],
  'M': [
    [Seg.line(Offset(0.10, 0.90), Offset(0.10, 0.10))],
    [Seg.line(Offset(0.10, 0.10), Offset(0.50, 0.55))],
    [Seg.line(Offset(0.50, 0.55), Offset(0.90, 0.10))],
    [Seg.line(Offset(0.90, 0.10), Offset(0.90, 0.90))],
  ],
  'N': [
    [Seg.line(Offset(0.15, 0.90), Offset(0.15, 0.10))],
    [Seg.line(Offset(0.15, 0.10), Offset(0.85, 0.90))],
    [Seg.line(Offset(0.85, 0.90), Offset(0.85, 0.10))],
  ],
  'O': [
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), math.pi / 2, math.pi)],
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.80, 0.80), -math.pi / 2, math.pi)],
  ],
  'P': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.22, 0.90))],
    [Seg.arc(Rect.fromLTWH(0.22, 0.10, 0.58, 0.44), -math.pi / 2, math.pi)],
  ],
  'Q': [
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.75, 0.75), math.pi / 2, math.pi)],
    [Seg.arc(Rect.fromLTWH(0.10, 0.10, 0.75, 0.75), -math.pi / 2, math.pi)],
    [Seg.line(Offset(0.60, 0.62), Offset(0.90, 0.90))],
  ],
  'R': [
    [Seg.line(Offset(0.22, 0.10), Offset(0.22, 0.90))],
    [Seg.arc(Rect.fromLTWH(0.22, 0.10, 0.58, 0.44), -math.pi / 2, math.pi)],
    [Seg.line(Offset(0.46, 0.54), Offset(0.84, 0.90))],
  ],
  'S': [
    [Seg.arc(Rect.fromLTWH(0.14, 0.08, 0.72, 0.44), math.pi * 0.50, math.pi * 0.80)],
    [Seg.arc(Rect.fromLTWH(0.14, 0.48, 0.72, 0.44), -math.pi * 0.50, math.pi * 0.80)],
  ],
  'T': [
    [Seg.line(Offset(0.10, 0.12), Offset(0.90, 0.12))],
    [Seg.line(Offset(0.50, 0.12), Offset(0.50, 0.92))],
  ],
  'U': [
    [Seg.line(Offset(0.20, 0.10), Offset(0.20, 0.65))],
    [
      Seg.arc(Rect.fromLTWH(0.20, 0.40, 0.60, 0.50), math.pi, math.pi),
      Seg.line(Offset(0.80, 0.65), Offset(0.80, 0.10)),
    ],
  ],
  'V': [
    [Seg.line(Offset(0.10, 0.10), Offset(0.50, 0.90))],
    [Seg.line(Offset(0.50, 0.90), Offset(0.90, 0.10))],
  ],
  'W': [
    [Seg.line(Offset(0.05, 0.10), Offset(0.28, 0.90))],
    [Seg.line(Offset(0.28, 0.90), Offset(0.50, 0.50))],
    [Seg.line(Offset(0.50, 0.50), Offset(0.72, 0.90))],
    [Seg.line(Offset(0.72, 0.90), Offset(0.95, 0.10))],
  ],
  'X': [
    [Seg.line(Offset(0.10, 0.10), Offset(0.90, 0.90))],
    [Seg.line(Offset(0.90, 0.10), Offset(0.10, 0.90))],
  ],
  'Y': [
    [Seg.line(Offset(0.10, 0.10), Offset(0.50, 0.50))],
    [Seg.line(Offset(0.90, 0.10), Offset(0.50, 0.50))],
    [Seg.line(Offset(0.50, 0.50), Offset(0.50, 0.90))],
  ],
  'Z': [
    [Seg.line(Offset(0.12, 0.12), Offset(0.88, 0.12))],
    [Seg.line(Offset(0.88, 0.12), Offset(0.12, 0.88))],
    [Seg.line(Offset(0.12, 0.88), Offset(0.88, 0.88))],
  ],
};

// ─── Public helpers ──────────────────────────────────────────────────────────
class LetterFragments {
  static Color colorOf(String letter) =>
      kLetterColors[letter.toUpperCase()] ?? Colors.grey;

  static int pieceCount(String letter) =>
      kPieces[letter.toUpperCase()]?.length ?? 2;

  static List<List<Seg>> piecesOf(String letter) =>
      kPieces[letter.toUpperCase()] ??
      [
        [const Seg.line(Offset(0.2, 0.5), Offset(0.8, 0.5))],
        [const Seg.line(Offset(0.5, 0.2), Offset(0.5, 0.8))],
      ];
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Draws a SINGLE piece on a board tile.
class PiecePainter extends CustomPainter {
  final String letter;
  final int pieceIndex;
  final Color color;

  const PiecePainter({
    required this.letter,
    required this.pieceIndex,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pieces = LetterFragments.piecesOf(letter);
    if (pieceIndex >= pieces.length) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final seg in pieces[pieceIndex]) {
      seg.draw(canvas, size, paint);
    }
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.pieceIndex != pieceIndex || old.letter != letter;
}

/// Draws the FULL letter shadow, lighting up collected pieces.
class ShadowPainter extends CustomPainter {
  final String letter;
  final Set<int> collected;
  final Color letterColor;

  const ShadowPainter({
    required this.letter,
    required this.collected,
    required this.letterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pieces = LetterFragments.piecesOf(letter);
    for (int i = 0; i < pieces.length; i++) {
      final isFilled = collected.contains(i);
      final paint = Paint()
        ..color = isFilled ? letterColor : Colors.white.withOpacity(0.18)
        ..strokeWidth = size.width * 0.10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (isFilled) {
        // glow
        final glow = Paint()
          ..color = letterColor.withOpacity(0.30)
          ..strokeWidth = size.width * 0.18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (final seg in pieces[i]) {
          seg.draw(canvas, size, glow);
        }
      }
      for (final seg in pieces[i]) {
        seg.draw(canvas, size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ShadowPainter old) =>
      old.collected != collected || old.letter != letter;
}
