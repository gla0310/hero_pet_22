import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// البيانات اللازمة لإنشاء PDF داخل الـ Isolate
class _PdfBuildParams {
  final String templateName;
  final String serviceTypeLabel;
  final String clientName;
  final String clientPhone;
  final String? civilId;
  final String? petName;
  final String? termsText;
  final bool termsAccepted;
  final List<Map<String, String>> answers;
  final Uint8List signatureBytes;
  final String? staffName;
  final String submittedAt;

  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;

  _PdfBuildParams({
    required this.templateName,
    required this.serviceTypeLabel,
    required this.clientName,
    required this.clientPhone,
    required this.civilId,
    required this.petName,
    required this.termsText,
    required this.termsAccepted,
    required this.answers,
    required this.signatureBytes,
    required this.staffName,
    required this.submittedAt,
    required this.regularFontBytes,
    required this.boldFontBytes,
  });
}

/// Worker دائم لإنشاء ملفات PDF في الخلفية.
class _PdfWorker {
  static _PdfWorker? _instance;

  static _PdfWorker get instance => _instance ??= _PdfWorker._();

  late final Future<SendPort> _workerSendPort;

  _PdfWorker._() {
    _workerSendPort = _spawn();
  }

  Future<SendPort> _spawn() async {
    final readyPort = ReceivePort();

    await Isolate.spawn(
      _workerEntry,
      readyPort.sendPort,
    );

    return await readyPort.first as SendPort;
  }

  Future<Uint8List> build(
    _PdfBuildParams params,
  ) async {
    final sendPort = await _workerSendPort;

    final responsePort = ReceivePort();

    sendPort.send([
      params,
      responsePort.sendPort,
    ]);

    final result = await responsePort.first;

    responsePort.close();

    if (result is Uint8List) {
      return result;
    }

    throw Exception(
      'فشل إنشاء PDF: $result',
    );
  }
}

/// نقطة تشغيل الـ Isolate
void _workerEntry(
  SendPort mainSendPort,
) {
  final receivePort = ReceivePort();

  mainSendPort.send(
    receivePort.sendPort,
  );

  pw.Font? cachedRegular;
  pw.Font? cachedBold;

  receivePort.listen(
    (message) async {
      final params = message[0] as _PdfBuildParams;

      final replyPort = message[1] as SendPort;

      try {
        if (cachedRegular == null && params.regularFontBytes != null) {
          cachedRegular = pw.Font.ttf(
            params.regularFontBytes!.buffer.asByteData(),
          );
        }

        if (cachedBold == null && params.boldFontBytes != null) {
          cachedBold = pw.Font.ttf(
            params.boldFontBytes!.buffer.asByteData(),
          );
        }

        if (cachedRegular == null || cachedBold == null) {
          throw Exception(
            'تعذر تحميل خطوط PDF',
          );
        }

        final bytes = await _buildPdfBytes(
          params,
          cachedRegular!,
          cachedBold!,
        );

        replyPort.send(bytes);
      } catch (e) {
        replyPort.send(
          e.toString(),
        );
      }
    },
  );
}

/// مولد ملفات PDF للاستبيانات والاستمارات.
class FormPdfGenerator {
  static const _uuid = Uuid();

  static Uint8List? _regularFontBytesCache;
  static Uint8List? _boldFontBytesCache;

  static Future<String> generate({
    required String templateName,
    required String serviceTypeLabel,
    required String clientName,
    required String clientPhone,
    String? civilId,
    String? petName,
    required String? termsText,
    required bool termsAccepted,
    required List<Map<String, String>> answers,
    required Uint8List signatureBytes,
    String? staffName,
    required String submittedAt,
  }) async {
    final sw = Stopwatch()..start();

    /// تحميل الخطوط مرة واحدة فقط
    _regularFontBytesCache ??= (await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    ))
        .buffer
        .asUint8List();

    _boldFontBytesCache ??= (await rootBundle.load(
      'assets/fonts/NotoSansArabic-Bold.ttf',
    ))
        .buffer
        .asUint8List();

    debugPrint(
      '⏱ [PDF] تحميل بايتات الخط: '
      '${sw.elapsedMilliseconds}ms',
    );

    sw.reset();

    final params = _PdfBuildParams(
      templateName: templateName,
      serviceTypeLabel: serviceTypeLabel,
      clientName: clientName,
      clientPhone: clientPhone,
      civilId: civilId,
      petName: petName,
      termsText: termsText,
      termsAccepted: termsAccepted,
      answers: answers,
      signatureBytes: signatureBytes,
      staffName: staffName,
      submittedAt: submittedAt,
      regularFontBytes: _regularFontBytesCache,
      boldFontBytes: _boldFontBytesCache,
    );

    final pdfBytes = await _PdfWorker.instance.build(
      params,
    );

    debugPrint(
      '⏱ [PDF] بناء المستند: '
      '${sw.elapsedMilliseconds}ms',
    );

    sw.reset();

    final docsDir = await getApplicationDocumentsDirectory();

    final formsDir = Directory(
      p.join(
        docsDir.path,
        'forms',
      ),
    );

    if (!await formsDir.exists()) {
      await formsDir.create(
        recursive: true,
      );
    }

    final fileName = '${_uuid.v4()}.pdf';

    final filePath = p.join(
      formsDir.path,
      fileName,
    );

    await File(filePath).writeAsBytes(
      pdfBytes,
      flush: true,
    );

    debugPrint(
      '⏱ [PDF] حفظ الملف: '
      '${sw.elapsedMilliseconds}ms',
    );

    return filePath;
  }
}

/// تنظيف النص من الرموز التي قد لا يدعمها الخط.
String _sanitize(
  String? input,
) {
  if (input == null || input.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();

  for (final rune in input.runes) {
    final allowed = rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        (rune >= 0x20 && rune <= 0x7E) ||
        (rune >= 0xA0 && rune <= 0xFF) ||
        (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);

    buffer.writeCharCode(
      allowed ? rune : 0x20,
    );
  }

  return buffer.toString();
}

///
/// تقسيم النص الطويل إلى أجزاء قصيرة.
///
/// هذه أهم نقطة في الحل.
///
/// بدل إعطاء مكتبة PDF نصًا واحدًا قد يصل ارتفاعه
/// إلى 800 أو 900 بكسل، نقسمه مسبقًا إلى أجزاء
/// صغيرة جدًا.
///
/// لا نحذف أي حرف.
List<String> _splitLongText(
  String text, {
  int maxChars = 500,
}) {
  final clean = _sanitize(text);

  if (clean.trim().isEmpty) {
    return [''];
  }

  final result = <String>[];

  /// نحافظ على الأسطر الأصلية قدر الإمكان.
  final paragraphs = clean.split(RegExp(r'\r?\n'));

  for (final paragraph in paragraphs) {
    final line = paragraph.trim();

    if (line.isEmpty) {
      result.add('');
      continue;
    }

    /// إذا كان السطر قصيرًا، نضيفه مباشرة.
    if (line.length <= maxChars) {
      result.add(line);
      continue;
    }

    /// إذا كان السطر طويلًا جدًا،
    /// نقسمه على المسافات حتى لا نقطع الكلمات.
    var remaining = line;

    while (remaining.length > maxChars) {
      var cut = remaining.lastIndexOf(
        ' ',
        maxChars,
      );

      /// في حال عدم وجود مسافة،
      /// نقطع عند الحد حتى لا يبقى Widget ضخم.
      if (cut <= 0) {
        cut = maxChars;
      }

      final part = remaining.substring(0, cut).trim();

      if (part.isNotEmpty) {
        result.add(part);
      }

      remaining = remaining.substring(cut).trim();
    }

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }
  }

  return result;
}

/// تحويل النص الطويل إلى Widgets صغيرة.
///
/// كل Widget صغير بما يكفي حتى لا يعطي:
/// Widget won't fit into the page
List<pw.Widget> _longTextWidgets(
  String text, {
  double fontSize = 10.5,
  double lineSpacing = 1.5,
  int maxChars = 500,
}) {
  final parts = _splitLongText(
    text,
    maxChars: maxChars,
  );

  final widgets = <pw.Widget>[];

  for (final part in parts) {
    if (part.isEmpty) {
      widgets.add(
        pw.SizedBox(
          height: 4,
        ),
      );

      continue;
    }

    widgets.add(
      pw.Text(
        part,
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        softWrap: true,
        style: pw.TextStyle(
          fontSize: fontSize,
          lineSpacing: lineSpacing,
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(
        height: 2,
      ),
    );
  }

  return widgets;
}

/// بناء PDF.
Future<Uint8List> _buildPdfBytes(
  _PdfBuildParams params,
  pw.Font arabicFont,
  pw.Font arabicFontBold,
) async {
  final sw = Stopwatch()..start();

  final doc = pw.Document();

  final signatureImage = pw.MemoryImage(
    params.signatureBytes,
  );

  final theme = pw.ThemeData.withFont(
    base: arabicFont,
    bold: arabicFontBold,
    fontFallback: [
      pw.Font.helvetica(),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,

      margin: const pw.EdgeInsets.fromLTRB(
        32,
        35,
        32,
        40,
      ),

      theme: theme,

      textDirection: pw.TextDirection.rtl,

      /// نسمح بعدد كبير جدًا من الصفحات.
      /// عدد الصفحات لا يهم، المهم عدم فقدان أي محتوى.
      maxPages: 1000,

      header: (context) {
        if (context.pageNumber == 1) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'hero pet',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(
                height: 4,
              ),
              pw.Text(
                _sanitize(
                  params.templateName,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(
                height: 2,
              ),
              pw.Text(
                _sanitize(
                  params.serviceTypeLabel,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(
                height: 6,
              ),
              pw.Divider(),
              pw.SizedBox(
                height: 4,
              ),
            ],
          );
        }

        return pw.Column(
          children: [
            pw.Text(
              'hero pet',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(
              height: 3,
            ),
            pw.Divider(),
            pw.SizedBox(
              height: 3,
            ),
          ],
        );
      },

      footer: (context) {
        return pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        );
      },

      build: (context) {
        final widgets = <pw.Widget>[];

        // ============================================================
        // بيانات العميل والأليف
        // ============================================================

        widgets.add(
          _sectionTitle(
            'بيانات العميل والأليف',
          ),
        );

        widgets.add(
          _row(
            'اسم العميل',
            params.clientName,
          ),
        );

        widgets.add(
          _row(
            'رقم الجوال',
            params.clientPhone,
          ),
        );

        if (params.civilId != null && params.civilId!.trim().isNotEmpty) {
          widgets.add(
            _row(
              'رقم الهوية / الإقامة',
              params.civilId!,
            ),
          );
        }

        if (params.petName != null && params.petName!.trim().isNotEmpty) {
          widgets.add(
            _row(
              'اسم الأليف',
              params.petName!,
            ),
          );
        }

        widgets.add(
          _row(
            'تاريخ ووقت الاستمارة',
            params.submittedAt,
          ),
        );

        if (params.staffName != null && params.staffName!.trim().isNotEmpty) {
          widgets.add(
            _row(
              'الموظف المستلم',
              params.staffName!,
            ),
          );
        }

        widgets.add(
          pw.SizedBox(
            height: 12,
          ),
        );

        // ============================================================
        // الشروط والأحكام
        // ============================================================

        if (params.termsText != null && params.termsText!.trim().isNotEmpty) {
          widgets.add(
            _sectionTitle(
              'الشروط والأحكام',
            ),
          );

          /// نقسم الشروط يدويًا.
          widgets.addAll(
            _longTextWidgets(
              params.termsText!,
              fontSize: 10.5,
              lineSpacing: 1.7,
              maxChars: 450,
            ),
          );

          widgets.add(
            pw.SizedBox(
              height: 5,
            ),
          );

          widgets.add(
            pw.Text(
              params.termsAccepted
                  ? 'تمت الموافقة على الشروط والأحكام'
                  : 'لم تتم الموافقة على الشروط والأحكام',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );

          widgets.add(
            pw.SizedBox(
              height: 14,
            ),
          );
        }

        // ============================================================
        // البنود والإجابات
        // ============================================================

        if (params.answers.isNotEmpty) {
          widgets.add(
            _sectionTitle(
              'البنود والإجابات',
            ),
          );

          for (final answer in params.answers) {
            final label = answer['label'] ?? '';

            final value = answer['value'] ?? '';

            // السؤال
            widgets.add(
              pw.Text(
                _sanitize(label),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
                softWrap: true,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );

            widgets.add(
              pw.SizedBox(
                height: 2,
              ),
            );

            // الإجابة
            if (value.trim().isEmpty) {
              widgets.add(
                pw.Text(
                  '—',
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(
                    fontSize: 10.5,
                  ),
                ),
              );
            } else {
              widgets.addAll(
                _longTextWidgets(
                  value,
                  fontSize: 10.5,
                  lineSpacing: 1.5,
                  maxChars: 400,
                ),
              );
            }

            widgets.add(
              pw.SizedBox(
                height: 8,
              ),
            );
          }

          widgets.add(
            pw.SizedBox(
              height: 5,
            ),
          );
        }

        // ============================================================
        // التوقيع
        // ============================================================

        widgets.add(
          pw.SizedBox(
            height: 5,
          ),
        );

        widgets.add(
          pw.Text(
            'توقيع العميل:',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

        widgets.add(
          pw.SizedBox(
            height: 6,
          ),
        );

        /// التوقيع حجمه ثابت وصغير.
        /// إذا لم يتسع في الصفحة، MultiPage ينقله
        /// حسب المساحة المتبقية.
        widgets.add(
          pw.Container(
            width: 220,
            height: 100,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                width: 0.5,
                color: PdfColors.grey600,
              ),
            ),
            child: pw.Image(
              signatureImage,
              fit: pw.BoxFit.contain,
            ),
          ),
        );

        return widgets;
      },
    ),
  );

  debugPrint(
    '⏱ [PDF/Worker] بناء تعريف الصفحات: '
    '${sw.elapsedMilliseconds}ms',
  );

  sw.reset();

  final bytes = await doc.save();

  debugPrint(
    '⏱ [PDF/Worker] doc.save(): '
    '${sw.elapsedMilliseconds}ms',
  );

  return bytes;
}

/// عنوان قسم.
pw.Widget _sectionTitle(
  String title,
) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(
      bottom: 7,
    ),
    padding: const pw.EdgeInsets.only(
      bottom: 4,
    ),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          width: 0.7,
          color: PdfColors.grey600,
        ),
      ),
    ),
    child: pw.Text(
      _sanitize(title),
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

/// صف بيانات العميل.
pw.Widget _row(
  String label,
  String value,
) {
  final safeLabel = _sanitize(label);

  final safeValue = _sanitize(value);

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(
      vertical: 2.5,
    ),
    child: pw.RichText(
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.right,
      softWrap: true,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$safeLabel: ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
            ),
          ),
          pw.TextSpan(
            text: safeValue,
            style: const pw.TextStyle(
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    ),
  );
}
