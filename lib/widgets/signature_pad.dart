import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// عنصر التوقيع الإلكتروني بالإصبع - يُستخدم داخل الاستمارات.
/// يوفر GlobalKey لتصدير التوقيع كصورة PNG عند الحفظ.
class SignaturePad extends StatefulWidget {
  final GlobalKey repaintKey;
  final VoidCallback? onChanged;

  const SignaturePad({super.key, required this.repaintKey, this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  bool get isEmpty => _strokes.isEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
    widget.onChanged?.call();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke?.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _currentStroke = null;
    widget.onChanged?.call();
  }

  /// يصدّر التوقيع الحالي كصورة PNG (bytes) - يُستخدم عند اعتماد الاستمارة
  Future<Uint8List?> exportPng() async {
    if (isEmpty) return null;
    final boundary = widget.repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.repaintKey,
      child: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _SignaturePainter(_strokes),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
