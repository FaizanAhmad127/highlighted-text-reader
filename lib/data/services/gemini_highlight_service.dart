import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/highlight.dart';
import 'gemini_highlight_parser.dart';
import 'page_image_compressor.dart';

class GeminiHighlightService {
  GeminiHighlightService({GenerativeModel? model}) : _model = model;

  GenerativeModel? _model;

  GenerativeModel get _generativeModel => _model ??= _createModel();

  static GenerativeModel _createModel() {
    final schema = Schema.object(
      properties: {
        'highlights': Schema.array(
          items: Schema.object(
            properties: {
              'text': Schema.string(),
              'literal': Schema.string(),
              'contextual': Schema.string(),
              'color': Schema.string(),
            },
          ),
        ),
      },
    );

    return FirebaseAI.googleAI().generativeModel(
      model: AppConstants.geminiModelId,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal),
      ),
      systemInstruction: Content.system(
        'You read a photo of a printed book or document page. '
        'Find only text that is marked with highlighter ink (any color). '
        'Do not invent phrases. If nothing is highlighted, return {"highlights":[]}. '
        'Preserve reading order (top to bottom, left to right). '
        'literal = short dictionary-style meaning. '
        'contextual = how the phrase is used in this sentence. '
        'color = highlighter ink as 0xAARRGGBB when you can see it.',
      ),
    );
  }

  Future<HighlightResponse> analyze(CompressedPageImage image) async {
    final response = await _generativeModel.generateContent([
      Content.multi([
        TextPart(
          'Extract every highlighted phrase from this page photo. '
          'Return JSON only.',
        ),
        InlineDataPart(image.mimeType, image.bytes),
      ]),
    ]);
    if (kDebugMode) {
      final usage = response.usageMetadata;
      debugPrint(
        'Gemini usageMetadata: prompt=${usage?.promptTokenCount}, '
        'candidates=${usage?.candidatesTokenCount}, '
        'thoughts=${usage?.thoughtsTokenCount}',
      );
    }
    return GeminiHighlightParser.parse(response.text);
  }
}
