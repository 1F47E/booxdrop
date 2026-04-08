class Quest {
  final String name;
  final double lat;
  final double lng;
  final String hint;
  final String flag;

  const Quest({
    required this.name,
    required this.lat,
    required this.lng,
    required this.hint,
    this.flag = '',
  });
}

class RoundResult {
  final Quest quest;
  final double guessLat;
  final double guessLng;
  final double distanceKm;
  final int points;
  final int stars;

  const RoundResult({
    required this.quest,
    required this.guessLat,
    required this.guessLng,
    required this.distanceKm,
    required this.points,
    required this.stars,
  });
}
