const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

String _belowThousand(int n) {
  if (n == 0) return '';
  if (n < 20) return _ones[n];
  if (n < 100) {
    return _tens[n ~/ 10] + (n % 10 != 0 ? ' ${_ones[n % 10]}' : '');
  }
  final rest = n % 100;
  return '${_ones[n ~/ 100]} Hundred${rest != 0 ? ' ${_belowThousand(rest)}' : ''}';
}

/// Spells out a rupee amount the Nepali/Indian way — grouped by
/// thousand/lakh/crore, not the Western million/billion split. Mirrors
/// client/src/utils/amountInWords.js so both platforms' bills read
/// identically. Rounds to the nearest rupee; paisa isn't printed on a bill.
String amountInWords(num amount, {String currency = 'Rupees', String onlySuffix = 'Only'}) {
  final n = amount.abs().round();
  if (n == 0) return 'Zero $currency $onlySuffix';

  final crore = n ~/ 10000000;
  final lakh = (n % 10000000) ~/ 100000;
  final thousand = (n % 100000) ~/ 1000;
  final rest = n % 1000;

  final parts = <String>[];
  if (crore != 0) parts.add('${_belowThousand(crore)} Crore');
  if (lakh != 0) parts.add('${_belowThousand(lakh)} Lakh');
  if (thousand != 0) parts.add('${_belowThousand(thousand)} Thousand');
  if (rest != 0) parts.add(_belowThousand(rest));

  return '${parts.join(' ')} $currency $onlySuffix'.trim();
}
