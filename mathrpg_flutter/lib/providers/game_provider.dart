import 'package:flutter/foundation.dart';
import '../models/character.dart';
import '../models/game_state.dart';
import '../models/item.dart';
import '../models/monster.dart';
import '../services/monster_factory.dart';
import '../services/save_service.dart';

enum GamePhase {
  home,
  characterCreation,
  adventureMap,
  battle,
  victory,
  defeat,
  inventory,
  characterSheet,
  settings,
}

class GameProvider extends ChangeNotifier {
  // Phase
  GamePhase _phase = GamePhase.home;
  GamePhase get phase => _phase;

  // Character
  Character? _character;
  Character? get character => _character;

  // Save state
  bool _hasSave = false;
  bool get hasSave => _hasSave;

  // Adventure
  late List<AdventureNode> _nodes;
  List<AdventureNode> get nodes => _nodes;

  // Current battle info (set when entering battle)
  Monster? _currentMonster;
  Monster? get currentMonster => _currentMonster;
  int? _currentNodeIndex;
  int? get currentNodeIndex => _currentNodeIndex;

  // Victory rewards (set after battle)
  int _lastXpGained = 0;
  int get lastXpGained => _lastXpGained;
  int _lastGoldGained = 0;
  int get lastGoldGained => _lastGoldGained;
  Item? _lastLoot;
  Item? get lastLoot => _lastLoot;
  int _lastLevelsGained = 0;
  int get lastLevelsGained => _lastLevelsGained;

  // Banner
  String? _banner;
  String? get banner => _banner;
  String? _bannerType;
  String? get bannerType => _bannerType;

  GameProvider() {
    _nodes = MonsterFactory.buildAdventureNodes();
    _checkSave();
  }

  Future<void> _checkSave() async {
    _hasSave = await SaveService.hasSave();
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------

  void goHome() {
    _phase = GamePhase.home;
    _checkSave();
    notifyListeners();
  }

  void startNewGame() {
    _phase = GamePhase.characterCreation;
    notifyListeners();
  }

  Future<void> continueGame() async {
    final save = await SaveService.load();
    if (save == null) {
      _setBanner('No save found', 'error');
      return;
    }
    _character = save.character;
    _phase = GamePhase.adventureMap;
    notifyListeners();
  }

  void createCharacter(String name, CharacterClass cls) {
    _character = Character(name: name, characterClass: cls);
    _character!.fullHeal();
    _phase = GamePhase.adventureMap;
    _autoSave();
    notifyListeners();
  }

  void enterBattle(int globalNodeIndex) {
    final node = _nodes[globalNodeIndex];
    _currentNodeIndex = globalNodeIndex;
    _currentMonster = MonsterFactory.spawnForNode(node.zoneIndex, node.nodeIndex);
    _phase = GamePhase.battle;
    notifyListeners();
  }

  void onBattleVictory({
    required int xpGained,
    required int goldGained,
    required Item? loot,
    required int levelsGained,
  }) {
    _lastXpGained = xpGained;
    _lastGoldGained = goldGained;
    _lastLoot = loot;
    _lastLevelsGained = levelsGained;
    _phase = GamePhase.victory;
    notifyListeners();
  }

  void onBattleDefeat() {
    _phase = GamePhase.defeat;
    notifyListeners();
  }

  void collectVictoryRewards() {
    if (_character != null && _currentNodeIndex != null) {
      // Advance progress if this is the current frontier node
      final globalProgress =
          _character!.currentZone * 6 + _character!.currentNode;
      if (_currentNodeIndex! >= globalProgress) {
        final nextGlobal = _currentNodeIndex! + 1;
        _character!.currentZone = nextGlobal ~/ 6;
        _character!.currentNode = nextGlobal % 6;
        if (_character!.currentZone >= MonsterFactory.zones.length) {
          _character!.currentZone = MonsterFactory.zones.length - 1;
          _character!.currentNode = MonsterFactory.zones.last.nodeCount - 1;
        }
      }
    }
    _phase = GamePhase.adventureMap;
    _autoSave();
    notifyListeners();
  }

  void retryBattle() {
    _character?.fullHeal();
    _phase = GamePhase.battle;
    notifyListeners();
  }

  void retreatFromBattle() {
    _character?.fullHeal();
    _phase = GamePhase.adventureMap;
    _autoSave();
    notifyListeners();
  }

  void openInventory() {
    _phase = GamePhase.inventory;
    notifyListeners();
  }

  void openCharacterSheet() {
    _phase = GamePhase.characterSheet;
    notifyListeners();
  }

  void openSettings() {
    _phase = GamePhase.settings;
    notifyListeners();
  }

  void backToMap() {
    _phase = GamePhase.adventureMap;
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Inventory
  // -------------------------------------------------------------------

  void equipItem(Item item) {
    if (_character == null) return;
    final current = _character!.equipment[item.slot];
    if (current != null) {
      _character!.inventory.add(current);
    }
    _character!.inventory.remove(item);
    _character!.equipment[item.slot] = item;
    _autoSave();
    notifyListeners();
  }

  void unequipItem(ItemSlot slot) {
    if (_character == null) return;
    final item = _character!.equipment[slot];
    if (item != null) {
      _character!.inventory.add(item);
      _character!.equipment[slot] = null;
      _autoSave();
      notifyListeners();
    }
  }

  void sellItem(Item item) {
    if (_character == null) return;
    _character!.inventory.remove(item);
    _character!.gold += item.goldValue;
    _setBanner('Sold for ${item.goldValue}g', 'success');
    _autoSave();
    notifyListeners();
  }

  void equipLoot(Item item) {
    if (_character == null) return;
    final current = _character!.equipment[item.slot];
    if (current != null) {
      _character!.inventory.add(current);
    }
    _character!.equipment[item.slot] = item;
    _autoSave();
    notifyListeners();
  }

  void keepLoot(Item item) {
    if (_character == null) return;
    _character!.inventory.add(item);
    _autoSave();
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------

  Future<void> _autoSave() async {
    if (_character == null) return;
    await SaveService.save(GameSave(
      character: _character!,
      lastPlayed: DateTime.now(),
    ));
    _hasSave = true;
  }

  Future<void> deleteSave() async {
    await SaveService.deleteSave();
    _hasSave = false;
    _character = null;
    _phase = GamePhase.home;
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Banner
  // -------------------------------------------------------------------

  void _setBanner(String text, String type) {
    _banner = text;
    _bannerType = type;
    notifyListeners();
    if (type != 'error') {
      Future.delayed(const Duration(seconds: 4), () {
        if (_banner == text) {
          _banner = null;
          _bannerType = null;
          notifyListeners();
        }
      });
    }
  }

  void clearBanner() {
    _banner = null;
    _bannerType = null;
    notifyListeners();
  }
}
