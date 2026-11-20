import 'package:flutter/services.dart';

/// Reduces whatever was typed or pasted ("+91 97000 20101", "097000-20101") to the 10-digit mobile number.
String indianMobileDigits(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length > 10 && d.startsWith('91')) {
    d = d.substring(2);
  } else if (d.length > 10 && d.startsWith('0')) {
    d = d.substring(1);
  }
  return d.length > 10 ? d.substring(0, 10) : d;
}

/// Keeps a pasted +91 / 0 prefix from eating the last digits of the 10-digit limit.
class IndianMobileFormatter extends TextInputFormatter {
  const IndianMobileFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final text = indianMobileDigits(next.text);
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
