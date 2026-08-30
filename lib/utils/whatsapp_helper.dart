import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

/// نتيجة محاولة فتح واتساب
enum WhatsAppOpenResult { opened, notInstalled }

/// أداة مساعدة لفتح تطبيق واتساب برسالة جاهزة دون إرسالها تلقائياً،
/// الموظف هو من يضغط على زر الإرسال بنفسه. تحتوي أيضاً على كل قوالب
/// الرسائل الرسمية المعتمدة لـ Hero Pet.
class WhatsAppHelper {
  static String _cleanPhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '966${cleanPhone.substring(1)}';
    }
    return cleanPhone.replaceAll('+', '');
  }

  static Future<WhatsAppOpenResult> openWhatsAppWithMessage({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = _cleanPhone(phone);

    // نجرب أولاً رابط whatsapp:// المباشر (يفتح التطبيق المثبت فعلياً،
    // سواء كان العادي أو Business)
    final directUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(directUri)) {
        final ok = await launchUrl(directUri, mode: LaunchMode.externalApplication);
        if (ok) return WhatsAppOpenResult.opened;
      }
    } catch (_) {
      // نتجاهل ونجرب الرابط البديل
    }

    // في حال عدم توفره نستخدم رابط wa.me كخيار بديل (يعمل عبر المتصفح أيضاً)
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (ok) return WhatsAppOpenResult.opened;
    } catch (_) {
      // لا يوجد شيء يمكن فتحه
    }

    return WhatsAppOpenResult.notInstalled;
  }

  /// اللقب المناسب حسب جنس الأليف: بطلكم (ذكر) أو بطلتكم (أنثى)
  static String heroPronoun(String? gender) => gender == 'أنثى' ? 'بطلتكم' : 'بطلكم';

  // ==================== تذكير بموعد قادم ====================

  /// قالب 1: تذكير بموعد متابعة
  static String buildFollowUpAppointmentMessage({
    required String petName,
    required String weekday,
    required String date,
    String? notes,
  }) {
    return 'تذكير: بطلكم $petName لديه موعد متابعة في عيادة البطل الأليف يوم $weekday $date.\n\n'
        'تفاصيل الموعد: ${(notes == null || notes.isEmpty) ? '-' : notes}\n\n'
        'نسعد باستقبالكم وخدمة أبطالكم.';
  }

  /// قالب 2: تذكير بموعد تطعيم
  static String buildVaccinationAppointmentMessage({
    required String petName,
    required String weekday,
    required String date,
    String? notes,
  }) {
    return 'تذكير: بطلكم $petName لديه موعد تطعيم في عيادة البطل الأليف يوم $weekday $date.\n\n'
        'تفاصيل الموعد: ${(notes == null || notes.isEmpty) ? '-' : notes}\n\n'
        'نسعد باستقبالكم وخدمة أبطالكم.';
  }

  // ==================== تذكير بالخروج اليوم ====================

  /// قوالب 3-5: تذكير بخروج اليوم حسب نوع الحالة
  static String buildCheckoutDueMessage({
    required String petName,
    String? gender,
    required String kind, // من AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return 'الحمدلله على السلامة، اليوم موعد خروج $pronoun $petName من الفندقة العلاجية.\n\n'
          'نسعد باستقبالكم وخدمة أبطالكم.';
    }
    if (kind == AdmissionKind.procedure) {
      return 'الحمدلله على السلامة، اليوم موعد خروج $pronoun $petName بعد الإجراء الطبي.\n\n'
          'نسعد باستقبالكم وخدمة أبطالكم.';
    }
    return 'تذكير: اليوم موعد خروج $pronoun $petName من الفندقة العادية.\n\n'
        'نسعد باستقبالكم وخدمة أبطالكم.';
  }

  // ==================== تأكيد تسجيل الدخول ====================

  /// قوالب 6-8: تأكيد تسجيل الدخول حسب نوع الحالة
  static String buildCheckinConfirmationMessage({
    required String petName,
    String? gender,
    required String kind, // من AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return 'تم تسجيل دخول $pronoun $petName في الفندقة العلاجية.\n\n'
          'نسعد بخدمتكم والاهتمام ببطلنا.';
    }
    if (kind == AdmissionKind.procedure) {
      return 'تم تسجيل دخول $pronoun $petName لإجراءه الطبي.\n\n'
          'نسعد بخدمتكم والاهتمام ببطلنا.';
    }
    return 'تم تسجيل دخول $pronoun $petName في الفندقة.\n\n'
        'نسعد بخدمتكم والاهتمام ببطلنا.';
  }

  // ==================== تأكيد تسجيل الخروج ====================

  /// قوالب 9-11: تأكيد تسجيل الخروج حسب نوع الحالة
  static String buildCheckoutConfirmationMessage({
    required String petName,
    String? gender,
    required String kind, // من AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return 'تم تسجيل خروج $pronoun $petName من الفندقة العلاجية.\n\n'
          'نسعد بخدمتكم دائمًا.';
    }
    if (kind == AdmissionKind.procedure) {
      return 'تم تسجيل خروج $pronoun $petName بعد الإجراء الطبي.\n\n'
          'نسعد بخدمتكم دائمًا.';
    }
    return 'تم تسجيل خروج $pronoun $petName من الفندقة.\n\n'
        'نسعد بخدمتكم دائمًا.';
  }

  // ==================== انتهاء خدمة الشاور والحلاقة ====================

  /// رسالة انتهاء خدمة الشاور/الحلاقة - تُظهر ضمير المذكر/المؤنث لكل من
  /// "بطلكم/بطلتكم" و"هو/هي" حسب جنس الأليف
  static String buildGroomingCompletedMessage({
    required String petName,
    String? gender,
  }) {
    final pronoun = heroPronoun(gender);
    final heShe = gender == 'أنثى' ? 'هي' : 'هو';
    return 'بشرى: انتهت خدمة $pronoun $petName و$heShe الآن بانتظاركم.\n\n'
        'نسعد باستقبالكم وخدمة أبطالكم.';
  }

  // ==================== موعد خروج اليوم (من شاشة المتواجدين في الفندقة) ====================

  /// رسالة موحّدة لكل أنواع الفندقة (عادية/علاجية) عندما يكون موعد خروج
  /// الأليف اليوم - تُستخدم من شاشة "المتواجدون حالياً في الفندقة"
  static String buildHotelCheckoutTodayMessage({
    required String petName,
    String? gender,
  }) {
    final pronoun = heroPronoun(gender);
    final suffix = gender == 'أنثى' ? 'ها' : 'ه';
    return '$pronoun $petName موعد خروج$suffix من الفندقة اليوم، متى حابين نجهز$suffix؟';
  }
}
