class PriceCalculator {
  PriceCalculator._();

  static const Map<String, double> _baseServicePrices = {
    'remorquage':   15000.0,
    'depannage':    10000.0,
    'crevaison':     5000.0,
    'batterie':      5000.0,
    'carburant':     3000.0,
    'default':       8000.0,
  };

  static double basePrice(String serviceTypeId) =>
      _baseServicePrices[serviceTypeId] ?? _baseServicePrices['default']!;

  static double kmCost(double distanceKm) => distanceKm * 500.0;

  static double total(String serviceTypeId, double distanceKm) =>
      basePrice(serviceTypeId) + kmCost(distanceKm);

  static double withSubscriptionDiscount(double price) => price * 0.70;

  static String formatFcfa(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$formatted FCFA';
  }
}
