import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ota_controller.dart';
import '../providers/game_provider.dart';
import '../services/monster_factory.dart';
import '../theme/eink_theme.dart';
import '../widgets/ota_menu_footer.dart';
import '../widgets/zone_node.dart';

class AdventureMapScreen extends StatelessWidget {
  const AdventureMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final ota = context.read<OtaController>();
    final character = game.character;
    if (character == null) return const SizedBox.shrink();

    final nodes = game.nodes;
    final globalProgress = character.currentZone * 6 + character.currentNode;

    // Determine current zone name
    final currentZoneIndex = character.currentZone.clamp(0, MonsterFactory.zones.length - 1);
    final currentZone = MonsterFactory.zones[currentZoneIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentZone.emoji} ${currentZone.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Lv.${character.level}  ${character.gold}g',
                style: const TextStyle(
                  fontSize: EinkSizes.textBody,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings',
                    style: TextStyle(fontSize: EinkSizes.textBody)),
                onTap: () {
                  Navigator.pop(context);
                  game.openSettings();
                },
              ),
              const Spacer(),
              OtaMenuFooter(controller: ota),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Banner
          if (game.banner != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: game.bannerType == 'error'
                  ? EinkColors.error
                  : game.bannerType == 'success'
                      ? EinkColors.success
                      : EinkColors.manaBlue,
              child: Text(
                game.banner!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EinkColors.white,
                  fontSize: EinkSizes.textBody,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Map nodes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // Show nodes in reverse so latest is at top
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final reverseIndex = nodes.length - 1 - index;
                final node = nodes[reverseIndex];
                final monster = MonsterFactory.spawnForNode(
                    node.zoneIndex, node.nodeIndex);
                final isCompleted = reverseIndex < globalProgress;
                final isCurrent = reverseIndex == globalProgress;
                final isLocked = reverseIndex > globalProgress;

                return ZoneNode(
                  monsterName: monster.name,
                  monsterEmoji: monster.emoji,
                  nodeIndex: reverseIndex,
                  isBoss: node.isBoss,
                  isCurrent: isCurrent,
                  isCompleted: isCompleted,
                  isLocked: isLocked,
                  element: monster.element,
                  onTap: () => game.enterBattle(reverseIndex),
                );
              },
            ),
          ),
          // Bottom bar
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: EinkColors.black)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: EinkSizes.tapTarget,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EinkColors.black,
                        side: const BorderSide(color: EinkColors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Text('\u{1F392}',
                          style: TextStyle(fontSize: 20)),
                      label: const Text('Inventory',
                          style: TextStyle(fontSize: EinkSizes.textBody)),
                      onPressed: game.openInventory,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: EinkSizes.tapTarget,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EinkColors.black,
                        side: const BorderSide(color: EinkColors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Text('\u{1F4CA}',
                          style: TextStyle(fontSize: 20)),
                      label: const Text('Stats',
                          style: TextStyle(fontSize: EinkSizes.textBody)),
                      onPressed: game.openCharacterSheet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
