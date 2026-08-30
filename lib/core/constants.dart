/// Different pet statuses depending on their location
class PetStatus {
  static const String normal = 'Normal'; // No current procedure
  static const String inHotel = 'In Hotel';
  static const String checkedOut = 'Checked Out';
  static const String inClinic = 'In Clinic';
  static const String delivered = 'Delivered';
}

/// Boarding types
class BoardingType {
  static const String treatment = 'Treatment Boarding';
  static const String normal = 'Regular Boarding';
}

/// Admission types in the Admissions table
class AdmissionType {
  static const String hotel = 'hotel';
  static const String procedure = 'procedure';
}

/// Reasons for a clinic visit
class VisitReason {
  static const String checkup = 'Checkup';
  static const String followUp = 'Follow-up';
  static const String vaccination = 'Vaccination';
  static const String procedure = 'Medical Procedure';
  static const String grooming = 'Grooming & Bathing';
  static const String other = 'Other';

  static const List<String> all = [checkup, followUp, vaccination, procedure, grooming, other];
}

/// Common pet types (also editable by the user as a free-text field)
class PetTypes {
  static const List<String> common = ['Cat', 'Dog', 'Bird', 'Rabbit', 'Other'];
}

/// Appointment status
class AppointmentStatus {
  static const String pending = 'Pending';
  static const String attended = 'Attended';
  static const String noShow = 'No Show';
  static const String cancelled = 'Cancelled';
  static const String rescheduled = 'Rescheduled';

  static const List<String> all = [pending, attended, noShow, cancelled, rescheduled];
}

/// Service types that electronic forms are linked to - each service type can
/// have one active form template. It appears automatically when the matching
/// service is selected.
/// Grooming & bathing department services - more than one category can be
/// selected in the same operation
class GroomingServiceType {
  static const String hygienePackage = 'Hygiene Package'; // Checkup + Haircut + Bath
  static const String healthPackage = 'Health Package'; // Checkup + Haircut + Therapeutic Bath
  static const String showerNormal = 'Regular Bath';
  static const String showerTreatment = 'Therapeutic Bath';
  static const String haircut = 'Haircut';

  static const List<String> all = [hygienePackage, healthPackage, showerNormal, showerTreatment, haircut];

  /// All services count as a bath for the loyalty counter, except "Haircut" on its own
  static bool servicesCountAsShower(List<String> selected) {
    return selected.any((s) => s != haircut);
  }
}

/// Grooming & bathing service status
class GroomingStatus {
  static const String pending = 'Pending';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';

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
        return 'Regular Hotel Check-in';
      case checkoutHotelNormal:
        return 'Regular Hotel Check-out';
      case checkinHotelTreatment:
        return 'Treatment Hotel Check-in';
      case checkoutHotelTreatment:
        return 'Treatment Hotel Check-out';
      case checkinProcedure:
        return 'Medical Procedure Check-in';
      case checkoutProcedure:
        return 'Medical Procedure Check-out';
      case 'procedure': // Legacy key before the split - for compatibility with any unmigrated data
        return 'Medical Procedures';
      default:
        return key;
    }
  }
}

/// Appointment type - used in the appointments screen
class AppointmentType {
  static const String followUp = 'Follow-up';
  static const String vaccination = 'Vaccination';
  static const String procedure = 'Medical Procedure';
  static const String grooming = 'Grooming & Bathing';
  static const String other = 'Other';

  static const List<String> all = [followUp, vaccination, procedure, grooming, other];
}

/// Options for the "next appointment" reason, which can be created directly from the clinic visit screen
class FollowUpReason {
  static const String followUp = 'Follow-up';
  static const String vaccination = 'Vaccination';
  static const String procedure = 'Medical Procedure';
  static const String grooming = 'Grooming & Bathing';
  static const String other = 'Other';

  static const List<String> all = [followUp, vaccination, procedure, grooming, other];
}

/// Admission type when checking a pet in (regular boarding / treatment boarding / medical procedure)
/// This is the unified choice shown to staff on the "check-in" screen,
/// which is then translated internally into (type + boardingType) in the Admissions table.
class AdmissionKind {
  static const String hotelNormal = 'Regular Boarding';
  static const String hotelTreatment = 'Treatment Boarding';
  static const String procedure = 'Medical Procedure';

  static const List<String> all = [hotelNormal, hotelTreatment, procedure];

  static bool isProcedure(String kind) => kind == procedure;
}
