import 'package:flutter/material.dart';
import 'package:country_code_picker_plus/country_code_picker_plus.dart';
import '../../../core/constants/app_constants.dart';

class PhoneInputWidget extends StatelessWidget {
  final TextEditingController phoneController;
  final Function(String) onCountryCodeChanged;
  final Function(String) onPhoneChanged;

  const PhoneInputWidget({
    super.key,
    required this.phoneController,
    required this.onCountryCodeChanged,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CountryCodePicker(
            onInit: (countryCode) {
              onCountryCodeChanged(countryCode.toString());
            },
            onChanged: (countryCode) {
              onCountryCodeChanged(countryCode.toString());
            },
            initialSelection: 'PK',
            mode: CountryCodePickerMode.bottomSheet,
            showFlag: true,
            showDropDownButton: true,
          ),
          Expanded(
            child: TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '3029389334',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              keyboardType: TextInputType.phone,
              onChanged: onPhoneChanged,
            ),
          ),
        ],
      ),
    );
  }
}
