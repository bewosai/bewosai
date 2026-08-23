import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class _CountryCode {
  final String code;
  final String flag;
  final String name;
  const _CountryCode(this.code, this.flag, this.name);
}

// Nepal first/default per the business's home market; rest cover the
// diaspora and neighboring trade partners most likely to sign up next.
const List<_CountryCode> _countryCodes = [
  _CountryCode('+977', '🇳🇵', 'Nepal'),
  _CountryCode('+91', '🇮🇳', 'India'),
  _CountryCode('+1', '🇺🇸', 'USA/Canada'),
  _CountryCode('+44', '🇬🇧', 'UK'),
  _CountryCode('+971', '🇦🇪', 'UAE'),
  _CountryCode('+974', '🇶🇦', 'Qatar'),
  _CountryCode('+966', '🇸🇦', 'Saudi Arabia'),
  _CountryCode('+60', '🇲🇾', 'Malaysia'),
  _CountryCode('+61', '🇦🇺', 'Australia'),
  _CountryCode('+82', '🇰🇷', 'South Korea'),
  _CountryCode('+81', '🇯🇵', 'Japan'),
];

/// Splits a combined phone string (e.g. "+9779800000000") into its country
/// code and local number by longest-prefix match against the known list.
/// Falls back to Nepal with the whole string as the number when nothing
/// matches (e.g. legacy data saved before country codes existed).
(String code, String number) _splitPhone(String value) {
  final v = value.trim();
  if (v.isEmpty) return ('+977', '');
  _CountryCode? best;
  for (final c in _countryCodes) {
    if (v.startsWith(c.code)) {
      if (best == null || c.code.length > best.code.length) best = c;
    }
  }
  if (best != null) return (best.code, v.substring(best.code.length));
  return ('+977', v.replaceFirst('+', ''));
}

/// A phone input with a country-code dropdown (Nepal +977 default), wired
/// to an external [controller] that always holds the combined value with
/// no space (e.g. "+9779800000000") — matching the backend's
/// `^\+?\d{7,15}$` validation, which rejects any whitespace.
class PhoneCountryField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;

  const PhoneCountryField({
    super.key,
    required this.controller,
    this.labelText = 'Phone',
  });

  @override
  State<PhoneCountryField> createState() => _PhoneCountryFieldState();
}

class _PhoneCountryFieldState extends State<PhoneCountryField> {
  late String _code;
  late final TextEditingController _numberController;

  @override
  void initState() {
    super.initState();
    final (code, number) = _splitPhone(widget.controller.text);
    _code = code;
    _numberController = TextEditingController(text: number);
    _numberController.addListener(_sync);
  }

  @override
  void dispose() {
    _numberController.removeListener(_sync);
    _numberController.dispose();
    super.dispose();
  }

  void _sync() {
    final number = _numberController.text.trim();
    widget.controller.text = number.isEmpty ? '' : '$_code$number';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.navy300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _code,
              isDense: true,
              items: _countryCodes
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text('${c.flag} ${c.code}', style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _code = v);
                _sync();
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: widget.labelText),
          ),
        ),
      ],
    );
  }
}
