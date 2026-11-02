class CountryCodeItem {
  final String name;
  final String dialCode;
  final String flag;
  final String code;

  const CountryCodeItem({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.code,
  });
}

const List<CountryCodeItem> allCountryCodes = [
  CountryCodeItem(name: 'India', dialCode: '+91', flag: '🇮🇳', code: 'IN'),
  CountryCodeItem(name: 'United States', dialCode: '+1', flag: '🇺🇸', code: 'US'),
  CountryCodeItem(name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧', code: 'GB'),
  CountryCodeItem(name: 'United Arab Emirates', dialCode: '+971', flag: '🇦🇪', code: 'AE'),
  CountryCodeItem(name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦', code: 'SA'),
  CountryCodeItem(name: 'Canada', dialCode: '+1', flag: '🇨🇦', code: 'CA'),
  CountryCodeItem(name: 'Australia', dialCode: '+61', flag: '🇦🇺', code: 'AU'),
  CountryCodeItem(name: 'Germany', dialCode: '+49', flag: '🇩🇪', code: 'DE'),
  CountryCodeItem(name: 'France', dialCode: '+33', flag: '🇫🇷', code: 'FR'),
  CountryCodeItem(name: 'Singapore', dialCode: '+65', flag: '🇸🇬', code: 'SG'),
  CountryCodeItem(name: 'Pakistan', dialCode: '+92', flag: '🇵🇰', code: 'PK'),
  CountryCodeItem(name: 'Bangladesh', dialCode: '+880', flag: '🇧🇩', code: 'BD'),
  CountryCodeItem(name: 'Nepal', dialCode: '+977', flag: '🇳🇵', code: 'NP'),
  CountryCodeItem(name: 'Sri Lanka', dialCode: '+94', flag: '🇱🇰', code: 'LK'),
  CountryCodeItem(name: 'Qatar', dialCode: '+974', flag: '🇶🇦', code: 'QA'),
  CountryCodeItem(name: 'Kuwait', dialCode: '+965', flag: '🇰🇼', code: 'KW'),
  CountryCodeItem(name: 'Oman', dialCode: '+968', flag: '🇴🇲', code: 'OM'),
  CountryCodeItem(name: 'Malaysia', dialCode: '+60', flag: '🇲🇾', code: 'MY'),
  CountryCodeItem(name: 'Indonesia', dialCode: '+62', flag: '🇮🇩', code: 'ID'),
  CountryCodeItem(name: 'Philippines', dialCode: '+63', flag: '🇵🇭', code: 'PH'),
  CountryCodeItem(name: 'South Africa', dialCode: '+27', flag: '🇿🇦', code: 'ZA'),
  CountryCodeItem(name: 'Nigeria', dialCode: '+234', flag: '🇳🇬', code: 'NG'),
  CountryCodeItem(name: 'Kenya', dialCode: '+254', flag: '🇰🇪', code: 'KE'),
  CountryCodeItem(name: 'Brazil', dialCode: '+55', flag: '🇧🇷', code: 'BR'),
  CountryCodeItem(name: 'Mexico', dialCode: '+52', flag: '🇲🇽', code: 'MX'),
  CountryCodeItem(name: 'Russia', dialCode: '+7', flag: '🇷🇺', code: 'RU'),
  CountryCodeItem(name: 'China', dialCode: '+86', flag: '🇨🇳', code: 'CN'),
  CountryCodeItem(name: 'Japan', dialCode: '+81', flag: '🇯🇵', code: 'JP'),
  CountryCodeItem(name: 'South Korea', dialCode: '+82', flag: '🇰🇷', code: 'KR'),
  CountryCodeItem(name: 'Italy', dialCode: '+39', flag: '🇮🇹', code: 'IT'),
  CountryCodeItem(name: 'Spain', dialCode: '+34', flag: '🇪🇸', code: 'ES'),
  CountryCodeItem(name: 'Turkey', dialCode: '+90', flag: '🇹🇷', code: 'TR'),
  CountryCodeItem(name: 'Netherlands', dialCode: '+31', flag: '🇳🇱', code: 'NL'),
  CountryCodeItem(name: 'Switzerland', dialCode: '+41', flag: '🇨🇭', code: 'CH'),
  CountryCodeItem(name: 'Sweden', dialCode: '+46', flag: '🇸🇪', code: 'SE'),
  CountryCodeItem(name: 'Norway', dialCode: '+47', flag: '🇳🇴', code: 'NO'),
  CountryCodeItem(name: 'New Zealand', dialCode: '+64', flag: '🇳🇿', code: 'NZ'),
  CountryCodeItem(name: 'Ireland', dialCode: '+353', flag: '🇮🇪', code: 'IE'),
];
