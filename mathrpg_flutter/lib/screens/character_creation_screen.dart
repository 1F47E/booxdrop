import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/game_provider.dart';
import '../services/progression_service.dart';
import '../theme/eink_theme.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final _nameController = TextEditingController();
  CharacterClass _selectedClass = CharacterClass.warrior;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = classInfo[_selectedClass]!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<GameProvider>().goHome(),
        ),
        title: const Text('Create Hero'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hero Name',
              style: TextStyle(
                fontSize: EinkSizes.textBody,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: EinkSizes.textBody),
              decoration: InputDecoration(
                hintText: 'Enter name...',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: EinkColors.black, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: EinkColors.black, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Your Class',
              style: TextStyle(
                fontSize: EinkSizes.textBody,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: CharacterClass.values.map((cls) {
                final clsInfo = classInfo[cls]!;
                final selected = cls == _selectedClass;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedClass = cls),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selected ? EinkColors.primary : EinkColors.white,
                        border: Border.all(
                          color: selected
                              ? EinkColors.primary
                              : EinkColors.black,
                          width: selected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            clsInfo.emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            clsInfo.name,
                            style: TextStyle(
                              fontSize: EinkSizes.textBody,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? EinkColors.white
                                  : EinkColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Class preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: EinkColors.offWhite,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${info.emoji} ${info.name}',
                    style: const TextStyle(
                      fontSize: EinkSizes.textLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.description,
                    style: const TextStyle(
                      fontSize: EinkSizes.textSmall,
                      color: EinkColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'HP: ${ProgressionService.maxHpAt(1, _selectedClass)}  '
                    'ATK: ${ProgressionService.atkAt(1, _selectedClass)}  '
                    'DEF: ${ProgressionService.defAt(1, _selectedClass)}',
                    style: const TextStyle(
                      fontSize: EinkSizes.textBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Per level: HP +${info.hpGrowth}  ATK +${info.atkGrowth}  DEF +${info.defGrowth}',
                    style: const TextStyle(
                      fontSize: EinkSizes.textSmall,
                      color: EinkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: EinkSizes.buttonHeight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: EinkColors.white,
                  backgroundColor: EinkColors.accent,
                  side: const BorderSide(color: EinkColors.accent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  context
                      .read<GameProvider>()
                      .createCharacter(name, _selectedClass);
                },
                child: const Text(
                  'Start Quest!',
                  style: TextStyle(
                    fontSize: EinkSizes.textLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
