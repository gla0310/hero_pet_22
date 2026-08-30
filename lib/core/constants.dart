/// حالات الأليفة المختلفة حسب مكانها
class PetStatus {
  static const String normal = 'طبيعي'; // لا يوجد إجراء حالي
  static const String inHotel = 'موجودة في الفندقة';
  static const String checkedOut = 'تم الخروج';
  static const String inClinic = 'موجودة في العيادة';
  static const String delivered = 'تم التسليم';
}

/// أنواع الفندقة
class BoardingType {
  static const String treatment = 'فندقة علاجية';
  static const String normal = 'فندقة عادية';
}

/// أنواع الإدخال في جدول Admissions
class AdmissionType {
  static const String hotel = 'hotel';
  static const String procedure = 'procedure';
}

/// أسباب زيارة العيادة
class VisitReason {
  static const String checkup = 'فحص';
  static const String followUp = 'متابعة';
  static const String vaccination = 'تطعيم';
  static const String procedure = 'إجراء طبي';
  static const String grooming = 'شاور وحلاقة';
  static const String other = 'أخرى';

  static const List<String> all = [checkup, followUp, vaccination, procedure, grooming, other];
}

/// أنواع الأليفات الشائعة (قابلة للتعديل من المستخدم أيضاً كحقل حر)
class PetTypes {
  static const List<String> common = ['قط', 'كلب', 'طائر', 'أرنب', 'أخرى'];
}

/// حالة الموعد
class AppointmentStatus {
  static const String pending = 'بانتظار';
  static const String attended = 'حضر';
  static const String noShow = 'لم يحضر';
  static const String cancelled = 'أُلغي';
  static const String rescheduled = 'أُعيدت جدولته';

  static const List<String> all = [pending, attended, noShow, cancelled, rescheduled];
}

/// أنواع الخدمة التي تُربط بها الاستمارات الإلكترونية - كل نوع خدمة يمكن أن
/// يكون له قالب استمارة واحد نشط. يظهر تلقائياً عند اختيار الخدمة المطابقة.
/// خدمات قسم الشاور والحلاقة - يمكن اختيار أكثر من صنف في نفس العملية
class GroomingServiceType {
  static const String hygienePackage = 'باقة النظافة'; // فحص + حلاقة + شاور
  static const String healthPackage = 'الباقة الصحية'; // فحص + حلاقة + شاور علاجي
  static const String showerNormal = 'شاور عادي';
  static const String showerTreatment = 'شاور علاجي';
  static const String haircut = 'حلاقة';

  static const List<String> all = [hygienePackage, healthPackage, showerNormal, showerTreatment, haircut];

  /// كل الخدمات تُحتسب كشاور ضمن عداد الولاء ما عدا "حلاقة" بمفردها
  static bool servicesCountAsShower(List<String> selected) {
    return selected.any((s) => s != haircut);
  }
}

/// حالة خدمة الشاور والحلاقة
class GroomingStatus {
  static const String pending = 'انتظار';
  static const String inProgress = 'يخضع للخدمة';
  static const String completed = 'انتهى';

  static const List<String> all = [pending, inProgress, completed];
}

class FormServiceType {
  static const String checkinHotelNormal = 'checkin_hotel_normal';
  static const String checkoutHotelNormal = 'checkout_hotel_normal';
  static const String checkinHotelTreatment = 'checkin_hotel_treatment';
  static const String checkoutHotelTreatment = 'checkout_hotel_treatment';
  static const String checkinProcedure = 'checkin_procedure';
  static const String checkoutProcedure = 'checkout_procedure';

  static const List<String> all = [
    checkinHotelNormal,
    checkoutHotelNormal,
    checkinHotelTreatment,
    checkoutHotelTreatment,
    checkinProcedure,
    checkoutProcedure,
  ];

  static String label(String key) {
    switch (key) {
      case checkinHotelNormal:
        return 'دخول فندقة عادية';
      case checkoutHotelNormal:
        return 'خروج فندقة عادية';
      case checkinHotelTreatment:
        return 'دخول فندقة علاجية';
      case checkoutHotelTreatment:
        return 'خروج فندقة علاجية';
      case checkinProcedure:
        return 'دخول إجراء طبي';
      case checkoutProcedure:
        return 'خروج إجراء طبي';
      case 'procedure': // مفتاح قديم قبل الفصل - للتوافق مع أي بيانات لم تُهاجَر
        return 'الإجراءات الطبية';
      default:
        return key;
    }
  }
}

/// نوع الموعد - يُستخدم في شاشة المواعيد
class AppointmentType {
  static const String followUp = 'متابعة';
  static const String vaccination = 'تطعيم';
  static const String procedure = 'إجراء طبي';
  static const String grooming = 'شاور وحلاقة';
  static const String other = 'أخرى';

  static const List<String> all = [followUp, vaccination, procedure, grooming, other];
}

/// خيارات سبب "الموعد القادم" الذي يمكن إنشاؤه مباشرة من شاشة زيارة العيادة
class FollowUpReason {
  static const String followUp = 'متابعة';
  static const String vaccination = 'تطعيم';
  static const String procedure = 'إجراء طبي';
  static const String grooming = 'شاور وحلاقة';
  static const String other = 'أخرى';

  static const List<String> all = [followUp, vaccination, procedure, grooming, other];
}

/// نوع الحالة عند تسجيل دخول الأليفة (فندقة عادية / فندقة علاجية / إجراء طبي)
/// هذا هو الاختيار الموحّد الذي يظهر للموظف في شاشة "تسجيل دخول"،
/// ثم يُترجم داخلياً إلى (type + boardingType) في جدول Admissions.
class AdmissionKind {
  static const String hotelNormal = 'فندقة عادية';
  static const String hotelTreatment = 'فندقة علاجية';
  static const String procedure = 'إجراء طبي';

  static const List<String> all = [hotelNormal, hotelTreatment, procedure];

  static bool isProcedure(String kind) => kind == procedure;
}
