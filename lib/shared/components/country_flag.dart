import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Custom country flag widget that loads from local assets
/// Only includes flags for supported languages: US, SA, DE, ES, FR, IT, RU, TR, CN
class CountryFlag extends StatelessWidget {
  final String countryCode;
  final double? width;
  final double? height;

  const CountryFlag({
    super.key,
    required this.countryCode,
    this.width,
    this.height,
  });

  /// Create a CountryFlag from a country code
  factory CountryFlag.fromCountryCode(
    String countryCode, {
    double? width,
    double? height,
  }) {
    return CountryFlag(
      countryCode: countryCode.toLowerCase(),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowerCode = countryCode.toLowerCase();

    // List of supported country codes
    const supportedCodes = ['us', 'sa', 'de', 'es', 'fr', 'it', 'ru', 'tr', 'cn'];

    // Fallback to a placeholder if flag not found
    if (!supportedCodes.contains(lowerCode)) {
      return Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.flag,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SvgPicture.asset(
      'assets/flags/$lowerCode.svg',
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
}
