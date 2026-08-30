import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

/// Result of an attempt to open WhatsApp
enum WhatsAppOpenResult { opened, notInstalled }

/// A helper tool for opening the WhatsApp app with a ready-made message
/// without sending it automatically - staff press the send button themselves.
/// Also contains all of Hero Pet's official approved message templates.
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

    // First try the direct whatsapp:// link (opens whichever app is actually
    // installed, regular or Business)
    final directUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(directUri)) {
        final ok = await launchUrl(directUri, mode: LaunchMode.externalApplication);
        if (ok) return WhatsAppOpenResult.opened;
      }
    } catch (_) {
      // Ignore and try the fallback link
    }

    // If unavailable, use the wa.me link as a fallback (also works via browser)
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (ok) return WhatsAppOpenResult.opened;
    } catch (_) {
      // Nothing left to try
    }

    return WhatsAppOpenResult.notInstalled;
  }

  /// The appropriate title based on the pet's gender: "your hero" (male) or "your heroine" (female)
  static String heroPronoun(String? gender) => gender == 'Female' ? 'your heroine' : 'your hero';

  // ==================== Upcoming appointment reminder ====================

  /// Template 1: Follow-up appointment reminder
  static String buildFollowUpAppointmentMessage({
    required String petName,
    required String weekday,
    required String date,
    String? notes,
  }) {
    return 'Reminder: your hero $petName has a follow-up appointment at Hero Pet Clinic on $weekday $date.\n\n'
        'Appointment details: ${(notes == null || notes.isEmpty) ? '-' : notes}\n\n'
        'We look forward to welcoming you and serving your heroes.';
  }

  /// Template 2: Vaccination appointment reminder
  static String buildVaccinationAppointmentMessage({
    required String petName,
    required String weekday,
    required String date,
    String? notes,
  }) {
    return 'Reminder: your hero $petName has a vaccination appointment at Hero Pet Clinic on $weekday $date.\n\n'
        'Appointment details: ${(notes == null || notes.isEmpty) ? '-' : notes}\n\n'
        'We look forward to welcoming you and serving your heroes.';
  }

  // ==================== Today's check-out reminder ====================

  /// Templates 3-5: Today's check-out reminder based on admission type
  static String buildCheckoutDueMessage({
    required String petName,
    String? gender,
    required String kind, // From AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return 'Great news, today is $pronoun $petName\'s check-out day from treatment boarding.\n\n'
          'We look forward to welcoming you and serving your heroes.';
    }
    if (kind == AdmissionKind.procedure) {
      return 'Great news, today is $pronoun $petName\'s check-out day after the medical procedure.\n\n'
          'We look forward to welcoming you and serving your heroes.';
    }
    return 'Reminder: today is $pronoun $petName\'s check-out day from regular boarding.\n\n'
        'We look forward to welcoming you and serving your heroes.';
  }

  // ==================== Check-in confirmation ====================

  /// Templates 6-8: Check-in confirmation based on admission type
  static String buildCheckinConfirmationMessage({
    required String petName,
    String? gender,
    required String kind, // From AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return '$pronoun $petName has been checked in to treatment boarding.\n\n'
          'We are happy to serve you and look after our hero.';
    }
    if (kind == AdmissionKind.procedure) {
      return '$pronoun $petName has been checked in for the medical procedure.\n\n'
          'We are happy to serve you and look after our hero.';
    }
    return '$pronoun $petName has been checked in to boarding.\n\n'
        'We are happy to serve you and look after our hero.';
  }

  // ==================== Check-out confirmation ====================

  /// Templates 9-11: Check-out confirmation based on admission type
  static String buildCheckoutConfirmationMessage({
    required String petName,
    String? gender,
    required String kind, // From AdmissionKind
  }) {
    final pronoun = heroPronoun(gender);
    if (kind == AdmissionKind.hotelTreatment) {
      return '$pronoun $petName has been checked out of treatment boarding.\n\n'
          'We are always happy to serve you.';
    }
    if (kind == AdmissionKind.procedure) {
      return '$pronoun $petName has been checked out after the medical procedure.\n\n'
          'We are always happy to serve you.';
    }
    return '$pronoun $petName has been checked out of boarding.\n\n'
        'We are always happy to serve you.';
  }

  // ==================== Grooming & bathing service completed ====================

  /// Grooming/bathing completion message - shows the correct pronoun for
  /// "your hero/heroine" and "he/she" based on the pet's gender
  static String buildGroomingCompletedMessage({
    required String petName,
    String? gender,
  }) {
    final pronoun = heroPronoun(gender);
    final heShe = gender == 'Female' ? 'she' : 'he';
    return 'Good news: $pronoun $petName\'s service is complete and $heShe is now waiting for you.\n\n'
        'We look forward to welcoming you and serving your heroes.';
  }

  // ==================== Today's check-out (from the current guests screen) ====================

  /// A unified message for all boarding types (regular/treatment) when the
  /// pet's check-out day is today - used from the "currently in the hotel" screen
  static String buildHotelCheckoutTodayMessage({
    required String petName,
    String? gender,
  }) {
    final pronoun = heroPronoun(gender);
    final suffix = gender == 'Female' ? 'her' : 'him';
    return '$pronoun $petName is due to check out of boarding today, when would you like us to have $suffix ready?';
  }
}
