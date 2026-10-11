import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Where a speech bubble's tail points (visual spec §3, "Speech bubble").
enum BubbleTail {
  /// Up from the top edge's centre, toward Penny above it (onboarding).
  up,

  /// Down from the bottom edge near its left corner (Penny's replies).
  bottomStart,

  /// Down from the bottom edge near its right corner (the user's messages).
  bottomEnd,
}

/// The speech-bubble shape shared by onboarding and the Penny chat: a
/// radius-24 card with a 12 dp tail. The tail is part of the outline, so a
/// fill, a border and a shadow all follow it; its room is reported through
/// [dimensions], so a [ShapeDecoration] pads the content clear of it.
class BubbleBorder extends ShapeBorder {
  const BubbleBorder({required this.tail, this.side = BorderSide.none});

  static const radius = AppRadius.card;
  static const tailSize = 12.0;

  /// How far the tail's base sits in from the corner it leans toward.
  static const _inset = 18.0;

  final BubbleTail tail;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => tail == BubbleTail.up
      ? const EdgeInsets.only(top: tailSize)
      : const EdgeInsets.only(bottom: tailSize);

  Rect _body(Rect rect) => tail == BubbleTail.up
      ? Rect.fromLTRB(rect.left, rect.top + tailSize, rect.right, rect.bottom)
      : Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - tailSize);

  Path _tail(Rect body) {
    switch (tail) {
      case BubbleTail.up:
        final x = body.center.dx;
        return Path()
          ..moveTo(x - tailSize, body.top + 1)
          ..lineTo(x, body.top - tailSize)
          ..lineTo(x + tailSize, body.top + 1)
          ..close();
      case BubbleTail.bottomStart:
        final x = body.left + _inset;
        return Path()
          ..moveTo(x, body.bottom - 1)
          ..lineTo(x - 4, body.bottom + tailSize)
          ..lineTo(x + tailSize + 4, body.bottom - 1)
          ..close();
      case BubbleTail.bottomEnd:
        final x = body.right - _inset;
        return Path()
          ..moveTo(x, body.bottom - 1)
          ..lineTo(x + 4, body.bottom + tailSize)
          ..lineTo(x - tailSize - 4, body.bottom - 1)
          ..close();
    }
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = _body(rect);
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(radius))),
      _tail(body),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.strokeInset), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => BubbleBorder(tail: tail, side: side.scale(t));

  @override
  bool operator ==(Object other) => other is BubbleBorder && other.tail == tail && other.side == side;

  @override
  int get hashCode => Object.hash(tail, side);
}
