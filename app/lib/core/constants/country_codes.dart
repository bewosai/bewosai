/// Curated country-code list for phone login. Nepal is first/default since
/// Bewosai's SMS gateway (Sparrow) only delivers OTPs to +977 numbers —
/// other codes are still selectable (the backend falls back to emailing the
/// code to that account's on-file email instead).
class CountryCode {
  final String code;
  final String country;
  final String flag;
  const CountryCode(this.code, this.country, this.flag);
}

const List<CountryCode> kCountryCodes = [
  CountryCode('+977', 'Nepal', '🇳🇵'),
  CountryCode('+91', 'India', '🇮🇳'),
  CountryCode('+1', 'USA/Canada', '🇺🇸'),
  CountryCode('+44', 'UK', '🇬🇧'),
  CountryCode('+61', 'Australia', '🇦🇺'),
  CountryCode('+971', 'UAE', '🇦🇪'),
  CountryCode('+966', 'Saudi Arabia', '🇸🇦'),
  CountryCode('+974', 'Qatar', '🇶🇦'),
  CountryCode('+965', 'Kuwait', '🇰🇼'),
  CountryCode('+973', 'Bahrain', '🇧🇭'),
  CountryCode('+60', 'Malaysia', '🇲🇾'),
  CountryCode('+81', 'Japan', '🇯🇵'),
  CountryCode('+82', 'South Korea', '🇰🇷'),
  CountryCode('+880', 'Bangladesh', '🇧🇩'),
  CountryCode('+92', 'Pakistan', '🇵🇰'),
];
