// Ship types matching the server's FleetShipTypes exactly.
// Server names are PascalCase: "Carrier", "Battleship", "Cruiser", "Sub"
enum ShipType { carrier, battleship, cruiser, sub }

extension ShipTypeExt on ShipType {
  /// The server-side name (PascalCase, matches Go ShipType.Name).
  String get serverName {
    switch (this) {
      case ShipType.carrier:
        return 'Carrier';
      case ShipType.battleship:
        return 'Battleship';
      case ShipType.cruiser:
        return 'Cruiser';
      case ShipType.sub:
        return 'Sub';
    }
  }

  /// Display label for the UI.
  String get label {
    switch (this) {
      case ShipType.carrier:
        return 'Carrier';
      case ShipType.battleship:
        return 'Battleship';
      case ShipType.cruiser:
        return 'Cruiser';
      case ShipType.sub:
        return 'Sub';
    }
  }

  int get size {
    switch (this) {
      case ShipType.carrier:
        return 4;
      case ShipType.battleship:
        return 3;
      case ShipType.cruiser:
        return 2;
      case ShipType.sub:
        return 2;
    }
  }
}

class ShipPoint {
  final int x;
  final int y;
  const ShipPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is ShipPoint && other.x == x && other.y == y;

  @override
  int get hashCode => x * 31 + y;

  Map<String, int> toJson() => {'x': x, 'y': y};
}

class Ship {
  final ShipType type;
  final List<ShipPoint> cells;

  Ship(this.type, this.cells);

  int get size => cells.length;
  String get name => type.serverName;

  /// Serialise to the format the server expects in submit_fleet.
  Map<String, dynamic> toJson() => {
        'type': {'name': type.serverName, 'size': type.size},
        'cells': cells.map((c) => c.toJson()).toList(),
      };
}

/// The four required ship types in fleet order, matching FleetShipTypes on the server.
const List<ShipType> kFleetOrder = [
  ShipType.carrier,
  ShipType.battleship,
  ShipType.cruiser,
  ShipType.sub,
];
