import 'package:flutter/material.dart';
import 'package:iftook/helpers/myassets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String selectedCountry;
  final List<String> countries;
  final ValueChanged<String> onCountryChanged;
  final bool isExtended;
  final PreferredSize? bottom;

  CustomAppBar({
    super.key,
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
    this.isExtended = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Image.asset(MyAssets.appIconPNG, height: 80),
          const Spacer(),
          DropdownButton<String>(
            value: selectedCountry,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white),
            items: countries.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    Text(value),
                    const SizedBox(width: 8),
                    const Icon(Icons.language, color: Colors.white),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                onCountryChanged(newValue);
              }
            },
          ),
        ],
      ),
      bottom: isExtended ? bottom : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
