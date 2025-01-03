library money_input_formatter;

import 'package:flutter/services.dart';

class InvalidExpressionException implements Exception {}

class MoneyInputFormatter extends TextInputFormatter {
  /// Number of decimals allowed, defaults to 2
  final int precision;

  /// Character separating the thousands, defaults to period
  final String thousandSeparator;

  /// Character to separate the decimal digits, defaults to comma
  final String decimalSeparator;

  MoneyInputFormatter({
    this.decimalSeparator = ',',
    this.thousandSeparator = '.',
    this.precision = 2,
  }) {
    if (decimalSeparator == thousandSeparator) {
      throw Exception(
          'decimalSeparator cannot be the same as thousandSeparator');
    }
  }

  String applyMask(String value) {
    // Split the input into integer and decimal parts
    var parts = value.split(decimalSeparator);
    var integerPart = parts[0];
    var decimalPart = parts.length > 1 ? parts[1] : '';

    // Remove all non-numeric characters from integer part
    integerPart = integerPart.replaceAll(RegExp(r'\D'), '');

    // Add thousand separators to the integer part
    var formattedIntegerPart = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => thousandSeparator,
    );

    if(integerPart.startsWith('0') && integerPart.length > 1) {
      formattedIntegerPart = formattedIntegerPart.substring(1);
    }

    // Ensure decimal part respects the precision
    if (decimalPart.length > precision) {
      // Replace the last character of the decimal part with the last entered character
      decimalPart =
          decimalPart.substring(0, precision - 1) + value[value.length - 1];
    } else {
      // If the decimal part length is less than precision, just use it as is
      decimalPart = decimalPart;
    }

    // Handle the case where the decimal part might end with trailing zeros
    if (decimalPart.length == 1 && decimalPart[0] == '0') {
      decimalPart = '';
    }

    // Combine integer and decimal parts
    var result = decimalPart.isNotEmpty
        ? '$formattedIntegerPart$decimalSeparator$decimalPart'
        : formattedIntegerPart;

    // If the result ends with a decimal separator and no decimal part, remove the separator
    if (result.endsWith(decimalSeparator) && decimalPart.isEmpty) {
      result = result.substring(0, result.length - 1);
    }

    return result;
  }

  double numberValue(String val) {
    if (val.isEmpty) return 0;

    var stringVal = val
        .replaceAll(thousandSeparator, '')
        .replaceFirst(decimalSeparator, '.')
        .replaceFirst(',', '.');

    return double.tryParse(stringVal) ?? 0;
  }

  TextEditingValue formatEditUpdateCalculate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var newText = newValue.text
        .replaceAll('--', '')
        .replaceAll('+-', '-')
        .replaceAll(' ', '');
    var difference = newText.length - oldValue.text.length;

    // no changes
    if (newText == newValue.text) {
      return newValue;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: newValue.selection.baseOffset + difference - 1),
      composing: TextRange.empty,
    );
  }

  bool containsCalculations(TextEditingValue value) {
    return value.text.contains('-') ||
        value.text.contains('+') ||
        value.text.contains('(') ||
        value.text.contains('*') ||
        value.text.contains('/') ||
        value.text.contains(')');
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length == 1 &&
        (newValue.text == ',' || newValue.text == '.')) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }
    if (newValue.text == '') {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }
    if (newValue.text == '0') {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange.empty,
      );
    }

    if (containsCalculations(newValue)) {
      return formatEditUpdateCalculate(oldValue, newValue);
    }

    // Too many separators
    if (decimalSeparator.allMatches(newValue.text).length > 1) {
      return oldValue;
    }

    var masked = applyMask(newValue.text);

    // No changes
    if (masked == newValue.text) {
      return newValue;
    }

    var spacesBeforeCursor = 0;
    var oldCursor = oldValue.selection.baseOffset;
    for (var i = 0; i < oldCursor; i++) {
      if (oldValue.text[i] == thousandSeparator) {
        spacesBeforeCursor++;
      }
    }
    oldCursor -= spacesBeforeCursor;
    spacesBeforeCursor = 0;

    var newCursor = newValue.selection.baseOffset;
    for (var i = 0; i < newCursor; i++) {
      if (newValue.text[i] == thousandSeparator) {
        spacesBeforeCursor++;
      }
    }
    newCursor -= spacesBeforeCursor;

    var spacesToAdd = 0;
    var _charCount = 0;
    for (var i = 0; i < masked.length; i++) {
      if (masked[i] == thousandSeparator) {
        spacesToAdd++;
      } else {
        _charCount++;
        if (_charCount == newCursor) {
          break;
        }
      }
    }

    var offset = newCursor + spacesToAdd;

    if (newValue.text.endsWith(decimalSeparator)) {
      masked += decimalSeparator;
    } else if (newValue.text.endsWith('${decimalSeparator}0') &&
        newCursor - oldCursor >= 0) {
      masked += '${decimalSeparator}0';
    }

    return TextEditingValue(
        text: masked,
        selection: TextSelection.collapsed(
            offset: offset > masked.length ? masked.length : offset));
  }
}
