import 'package:flutter/material.dart';

import '../../../domain/entities/highlight.dart';

class ExpandableHighlightCard extends StatelessWidget {
  const ExpandableHighlightCard({
    super.key,
    required this.highlight,
    required this.expanded,
    required this.onTap,
    this.saved,
    this.onSave,
    this.caption,
  });

  final Highlight highlight;
  final bool expanded;
  final VoidCallback onTap;
  final bool? saved;
  final VoidCallback? onSave;
  final String? caption;

  Color get _inkColor =>
      Color(int.tryParse(highlight.color) ?? 0xFFE8C547);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = expanded
        ? theme.colorScheme.primary
        : theme.dividerColor;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _inkColor),
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highlight.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            expanded ? 'Hide meaning' : 'Tap for meaning',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (caption != null && caption!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              caption!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (onSave != null)
                  IconButton(
                    tooltip: saved == true ? 'Unsave' : 'Save',
                    icon: Icon(
                      saved == true ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: onSave,
                  ),
              ],
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Literal', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  SelectableText(
                    highlight.literal,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (highlight.contextual.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'In this sentence',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      highlight.contextual,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
