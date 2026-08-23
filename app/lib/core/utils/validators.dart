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

  // Domain is one or more "label." segments (supports subdomains like
  // user@mail.example.co) followed by a final 2+ letter TLD.
  static final _emailRegex = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static final _phoneRegex = RegExp(r'^\d{7,15}$');

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // phone is optional throughout the app
    if (!_phoneRegex.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static final _phoneDigitsRegex = RegExp(r'^\+?\d{7,15}$');

  /// Sign-in only accepts either — sign-up still requires [email], since
  /// phone-based accounts can't receive a code until an SMS provider is
  /// wired up server-side (see SendOTPView).
  static String? emailOrPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email or phone number';
    if (v.contains('@')) return email(v);
    if (!_phoneDigitsRegex.hasMatch(v)) return 'Enter a valid email or phone number';
    return null;
  }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the code';
    if (v.length != 6 || int.tryParse(v) == null) return 'Enter the 6-digit code';
    return null;
  }
}
