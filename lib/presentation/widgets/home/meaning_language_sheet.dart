import 'package:flutter/material.dart';

import '../../../domain/entities/meaning_language.dart';

class MeaningLanguageSheet extends StatefulWidget {
  const MeaningLanguageSheet({super.key, required this.selected});

  final MeaningLanguage selected;

  static Future<MeaningLanguage?> show(
    BuildContext context, {
    required MeaningLanguage selected,
  }) {
    return showModalBottomSheet<MeaningLanguage>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MeaningLanguageSheet(selected: selected),
    );
  }

  @override
  State<MeaningLanguageSheet> createState() => _MeaningLanguageSheetState();
}

class _MeaningLanguageSheetState extends State<MeaningLanguageSheet> {
  late MeaningLanguage _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = MeaningLanguageCatalog.listed(
      selected: _selected,
      query: _query,
    );
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meaning language',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used on the next scan. Highlighted phrases stay as they are.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search languages',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  final isSelected = language.id == _selected.id;
                  return ListTile(
                    title: Text(language.name),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(language),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
