/// `TextFormField.validator` helpers shared across every form in the app.
class Validators {
  static String? required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  /// Only validates when [value] is non-empty — pair with [required]
  /// separately when the field itself is mandatory.
  static String? positiveNumber(String? value, String field) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.trim());
    if (n == null) return '$field must be a number';
    if (n <= 0) return '$field must be greater than 0';
    return null;
  }

  /// A discount typed against something worth [gross] (a line's quantity × price,
  /// or an invoice subtotal). Only validates non-empty input; null means fine.
  static String? discount(String? value, double gross) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null) return 'Discount must be a number';
    if (n < 0) return "Discount can't be negative";
    if (n > gross + 0.005) return "Can't be more than ${gross.toStringAsFixed(2)}";
    return null;
  }

  /// The discount as it should count: never negative, never more than [gross],
  /// so a typo can't push a total below zero. Unparseable input counts as 0.
  static double cappedDiscount(String? value, double gross) {
    final n = double.tryParse((value ?? '').trim()) ?? 0;
    return n.clamp(0.0, gross < 0 ? 0.0 : gross).toDouble();
  }

  /// A line discount typed as a % of [gross] (capped to 0–100%) or, when
  /// [percent] is false, as rupees (see [cappedDiscount]) — returned in rupees,
  /// rounded to paisa.
  static double discountAmount(String? value, double gross, {bool percent = false}) {
    if (!percent) return cappedDiscount(value, gross);
    final pct = (double.tryParse((value ?? '').trim()) ?? 0).clamp(0.0, 100.0);
    final g = gross < 0 ? 0.0 : gross;
    return (g * pct / 100 * 100).round() / 100;
  }

  static String? discountPercent(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null) return 'Discount must be a number';
    if (n < 0) return "Discount can't be negative";
    if (n > 100) return "Can't be more than 100%";
    return null;
  }

  // Domain is one or more "label." segments (supports subdomains like
  // user@mail.example.co) followed by a final 2+ letter TLD.
  static final _emailRegex = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static final _phoneRegex = RegExp(r'^\+?\d{7,15}$');

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // phone is optional throughout the app
    if (!_phoneRegex.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  // Phone sign-in is built end-to-end (backend resolves either kind of
  // identifier — see accounts/views.py) but disabled in the UI for now.
  // To re-enable, uncomment this and swap it back in for Validators.email
  // on the login screen's identifier field.
  // static final _phoneDigitsRegex = RegExp(r'^\+?\d{7,15}$');
  // static String? emailOrPhone(String? value) {
  //   final v = value?.trim() ?? '';
  //   if (v.isEmpty) return 'Enter your email or phone number';
  //   if (v.contains('@')) return email(v);
  //   if (!_phoneDigitsRegex.hasMatch(v)) return 'Enter a valid email or phone number';
  //   return null;
  // }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the code';
    if (v.length != 6 || int.tryParse(v) == null) return 'Enter the 6-digit code';
    return null;
  }
}
