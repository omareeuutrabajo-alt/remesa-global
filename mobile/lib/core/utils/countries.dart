/// Catálogo de países del corredor de remesas.
class Country {
  const Country(this.iso, this.name, this.dialCode, this.flag, {this.currency = 'USD'});

  final String iso;
  final String name;
  final String dialCode;
  final String flag;
  final String currency;

  @override
  String toString() => '$flag $name ($dialCode)';
}

abstract final class Countries {
  static const List<Country> all = [
    Country('US', 'Estados Unidos', '+1', '🇺🇸'),
    Country('MX', 'México', '+52', '🇲🇽', currency: 'MXN'),
    Country('CO', 'Colombia', '+57', '🇨🇴', currency: 'COP'),
    Country('VE', 'Venezuela', '+58', '🇻🇪', currency: 'VES'),
    Country('DO', 'República Dominicana', '+1', '🇩🇴', currency: 'DOP'),
    Country('GT', 'Guatemala', '+502', '🇬🇹', currency: 'GTQ'),
    Country('HN', 'Honduras', '+504', '🇭🇳', currency: 'HNL'),
    Country('SV', 'El Salvador', '+503', '🇸🇻'),
    Country('NI', 'Nicaragua', '+505', '🇳🇮', currency: 'NIO'),
    Country('CR', 'Costa Rica', '+506', '🇨🇷', currency: 'CRC'),
    Country('PE', 'Perú', '+51', '🇵🇪', currency: 'PEN'),
    Country('EC', 'Ecuador', '+593', '🇪🇨'),
    Country('BO', 'Bolivia', '+591', '🇧🇴', currency: 'BOB'),
    Country('AR', 'Argentina', '+54', '🇦🇷', currency: 'ARS'),
    Country('CL', 'Chile', '+56', '🇨🇱', currency: 'CLP'),
    Country('BR', 'Brasil', '+55', '🇧🇷', currency: 'BRL'),
    Country('ES', 'España', '+34', '🇪🇸', currency: 'EUR'),
    Country('CU', 'Cuba', '+53', '🇨🇺', currency: 'CUP'),
    Country('HT', 'Haití', '+509', '🇭🇹', currency: 'HTG'),
    Country('PY', 'Paraguay', '+595', '🇵🇾', currency: 'PYG'),
  ];

  static Country byIso(String iso) =>
      all.firstWhere((c) => c.iso == iso, orElse: () => all.first);
}
