# Gemini Highlight Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace on-device OpenCV + ML Kit OCR + dictionary lookups with one Firebase AI Logic (Gemini 3.5 Flash-Lite) call that finds highlighter marks and returns literal + contextual meanings.

**Architecture:** `HomeScreen` still picks a photo and lists `Highlight` cards. A new `HighlightScanService` compresses the image, blocks when offline, and calls `GeminiHighlightService` (`FirebaseAI.googleAI()`, structured JSON). OpenCV, ML Kit, Datamuse, and Free Dictionary are deleted. Offline can no longer extract highlights.

**Tech Stack:** Flutter, `firebase_core` (already present), `firebase_ai`, `firebase_app_check`, `firebase_auth` (anonymous), Gemini Developer API, `image_picker`, `connectivity_plus`.

## Global Constraints

- Model id must be exactly `gemini-3.5-flash-lite` (not `-latest`, not 2.5/3.1 Lite, not full Flash).
- Provider must be `FirebaseAI.googleAI()` (Gemini Developer API), not Vertex / Agent Platform.
- Thinking must be `ThinkingLevel.minimal` (Flash-Lite default; set it explicitly).
- Resize so the long edge is at most 1536px and JPEG quality is 70 before upload.
- One `generateContent` per scan; never one request per highlight.
- Do not send raw 12MP / HEIC originals to Gemini.
- App Check must be activated after `Firebase.initializeApp` or quota will be abused.
- `npx firebase-tools init ailogic` (or Console → AI Services → AI Logic) is mandatory; `flutterfire configure` does not enable the API.
- Keep existing Analytics / Crashlytics wiring; do not log phrase text (no PII).
- Native OpenCV/ML Kit has no hand-written Podfile/Gradle entries; removing the Dart packages and rebuilding is enough (`Podfile.lock` regenerates).
- Leave `ios` 15.5 and Android `minSdk` 24 as they are. Leave `GoogleService-Info.plist` and `google-services.json` in place.
- Do not add a backend. Do not keep OpenCV/ML Kit as a fallback.
- Do not commit unless the user explicitly asks.

## File map

**Create**

- `lib/data/services/page_image_compressor.dart` — downscale + JPEG encode
- `lib/data/services/gemini_highlight_parser.dart` — JSON → `HighlightResponse` (no Firebase import)
- `lib/data/services/gemini_highlight_service.dart` — Gemini call
- `lib/data/services/highlight_scan_service.dart` — compress + call + errors
- `test/data/services/gemini_highlight_parser_test.dart`
- `test/data/services/page_image_compressor_test.dart`
- `test/domain/entities/highlight_test.dart`

**Modify**

- `lib/domain/entities/highlight.dart` — add `contextual`
- `lib/core/constants/app_constants.dart` — model name, image limits, copy
- `lib/core/firebase/firebase_bootstrap.dart` — App Check + anonymous Auth
- `lib/core/firebase/app_analytics.dart` — drop dictionary flag; add `ai_failure`
- `lib/home_screen.dart` — new service; remove meaning-refresh
- `lib/presentation/widgets/highlight/expandable_highlight_card.dart` — literal + contextual
- `lib/presentation/widgets/home/image_capture_section.dart` — offline copy
- `lib/presentation/pages/onboarding/onboarding_page.dart` — internet + both meanings
- `pubspec.yaml` — add AI packages; remove OpenCV / ML Kit / http / dartcv hooks

**Delete**

- `lib/data/services/text_processing_pipeline.dart`
- `lib/data/services/opencv_highlight_detector.dart`
- `lib/data/services/ocr_service.dart`
- `lib/data/services/highlight_extractor.dart`
- `lib/data/services/dictionary_meaning_service.dart`
- `lib/data/models/highlight_detection.dart`

**Keep**

- `lib/firebase_options.dart`, Analytics, Crashlytics, `connectivity_helper.dart`, image preview / full-screen viewer, routing, onboarding assets.

---

### Task 1: Enable AI Logic backend and add packages

**Files:**
- Modify: `pubspec.yaml`
- Manual: Firebase project `highlighted-text-reader`

**Interfaces:**
- Consumes: existing `firebase_core` 4.14.0
- Produces: `firebase_ai`, `firebase_app_check`, `firebase_auth` on the client; Gemini Developer API enabled on the project

- [ ] **Step 1: Provision the backend**

In the repo root (needs network + Firebase login):

```bash
npx -y firebase-tools@latest projects:list
npx -y firebase-tools@latest init ailogic
```

If the CLI is interactive, do the same in Firebase Console: **AI Services → AI Logic → Get started → Gemini Developer API**.

Confirm the project is `highlighted-text-reader`. Skipping this causes `PERMISSION_DENIED`.

- [ ] **Step 2: Add client packages and drop unused ones**

Replace `pubspec.yaml` dependencies / hooks with:

```yaml
dependencies:
    connectivity_plus: ^6.1.3
    firebase_ai: ^3.0.0
    firebase_analytics: ^12.5.0
    firebase_app_check: ^0.4.0
    firebase_auth: ^6.0.0
    firebase_core: ^4.14.0
    firebase_crashlytics: ^5.3.0
    flutter:
        sdk: flutter
    flutter_launcher_icons: ^0.14.3
    go_router: ^14.8.0
    image_picker: ^1.1.2
    introduction_screen: ^3.1.16
    package_rename: ^1.8.0
```

Delete the entire `hooks:` / `dartcv4` block. Remove `google_mlkit_text_recognition`, `http`, and `opencv_dart`.

Run:

```bash
flutter pub get
```

Expected: resolve succeeds. Do not run `pod install` until Task 8 (after Dart files no longer import OpenCV/ML Kit).

---

### Task 2: Extend `Highlight` with contextual meaning

**Files:**
- Modify: `lib/domain/entities/highlight.dart`
- Test: `test/domain/entities/highlight_test.dart`

**Interfaces:**
- Produces: `Highlight.text`, `Highlight.literal`, `Highlight.contextual`, `Highlight.color`, `Highlight.textColor`, `copyWith`, `HighlightResponse`

- [ ] **Step 1: Write the failing test**

Create `test/domain/entities/highlight_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';

void main() {
  test('copyWith updates contextual and keeps literal', () {
    const original = Highlight(
      text: 'due diligence',
      literal: 'careful investigation',
      contextual: 'Checking the company before buying it.',
      color: '0xFFE8C547',
      textColor: '0xFF000000',
    );

    final updated = original.copyWith(contextual: 'Updated context.');

    expect(updated.text, 'due diligence');
    expect(updated.literal, 'careful investigation');
    expect(updated.contextual, 'Updated context.');
    expect(updated.color, original.color);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/domain/entities/highlight_test.dart
```

Expected: compile error — `contextual` is not defined.

- [ ] **Step 3: Update the entity**

Replace `lib/domain/entities/highlight.dart` with:

```dart
class Highlight {
  final String text;
  final String literal;
  final String contextual;
  final String color;
  final String textColor;

  const Highlight({
    required this.text,
    required this.literal,
    required this.contextual,
    required this.color,
    required this.textColor,
  });

  Highlight copyWith({
    String? text,
    String? literal,
    String? contextual,
    String? color,
    String? textColor,
  }) {
    return Highlight(
      text: text ?? this.text,
      literal: literal ?? this.literal,
      contextual: contextual ?? this.contextual,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
    );
  }
}

class HighlightResponse {
  final bool found;
  final List<Highlight>? highlights;

  const HighlightResponse({
    required this.found,
    this.highlights,
  });

  HighlightResponse copyWith({
    bool? found,
    List<Highlight>? highlights,
  }) {
    return HighlightResponse(
      found: found ?? this.found,
      highlights: highlights ?? this.highlights,
    );
  }
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/domain/entities/highlight_test.dart
```

Expected: PASS. Until Task 9 deletes the old pipeline, add `contextual: ''` to existing `Highlight(` calls in `text_processing_pipeline.dart` so `dart analyze` stays green.

---

### Task 3: Add image compressor and constants

**Files:**
- Create: `lib/data/services/page_image_compressor.dart`
- Modify: `lib/core/constants/app_constants.dart`
- Test: `test/data/services/page_image_compressor_test.dart`

**Interfaces:**
- Produces: `PageImageCompressor.compress(File) → Future<CompressedPageImage>`
- `CompressedPageImage` fields: `bytes` (`Uint8List`), `mimeType` (`image/jpeg`)
- Constants: `geminiModelId = 'gemini-3.5-flash-lite'`, `maxImageEdgePx = 1536`, `jpegQuality = 70`

- [ ] **Step 1: Add constants**

Append to `lib/core/constants/app_constants.dart`:

```dart
  static const String geminiModelId = 'gemini-3.5-flash-lite';
  static const int maxImageEdgePx = 1536;
  static const int jpegQuality = 70;
```

Keep existing meaning placeholders until Task 6, then delete `meaningPendingPlaceholder` (offline no longer extracts text). Keep `meaningUnavailablePlaceholder` only if the parser still needs a fallback string; otherwise delete both and use parser-only empty lists.

- [ ] **Step 2: Implement compressor**

Create `lib/data/services/page_image_compressor.dart` using `dart:ui` (no extra package):

```dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/constants/app_constants.dart';

class CompressedPageImage {
  const CompressedPageImage({
    required this.bytes,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String mimeType;
}

class PageImageCompressor {
  const PageImageCompressor();

  Future<CompressedPageImage> compress(File imageFile) async {
    final raw = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      raw,
      targetWidth: AppConstants.maxImageEdgePx,
      targetHeight: AppConstants.maxImageEdgePx,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode the page photo.');
      }
      // Re-encode via image_picker constraints at pick time; this pass
      // guarantees long edge <= 1536. JPEG is produced in the scan service
      // when the picker already returned JPEG. If PNG bytes are large,
      // callers still benefit from the smaller pixel grid (4 Gemini tiles).
      return CompressedPageImage(bytes: data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }
}
```

Prefer JPEG for Gemini tokens/size. After `instantiateImageCodec`, if you can add `package:image` later, encode JPEG at quality 70. For this plan, also constrain the picker (Task 6):

```dart
_picker.pickImage(
  source: source,
  maxWidth: AppConstants.maxImageEdgePx.toDouble(),
  maxHeight: AppConstants.maxImageEdgePx.toDouble(),
  imageQuality: AppConstants.jpegQuality,
);
```

That picker pass is the main size reduction. The compressor is a second guard when a gallery file ignores picker limits (some HEIC paths).

If JPEG encode without a new dependency is awkward, implement compressor as:

```dart
class PageImageCompressor {
  const PageImageCompressor();

  Future<CompressedPageImage> compress(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return CompressedPageImage(
      bytes: bytes,
      mimeType: _mimeTypeFor(imageFile.path),
    );
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
```

and **require** the `pickImage` maxWidth/maxHeight/imageQuality arguments so the file on disk is already small. That is the intended production path.

- [ ] **Step 3: Test mime helper / byte pass-through**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/page_image_compressor.dart';

void main() {
  test('compress returns jpeg mime for .jpg paths', () async {
    final file = File('test/fixtures/tiny.jpg');
    // If no fixture exists, skip creating binary fixtures: unit-test _mimeTypeFor
    // by making it a top-level or visible function in the compressor file.
    expect(PageImageCompressor.mimeTypeFor(file.path), 'image/jpeg');
  });
}
```

Expose `PageImageCompressor.mimeTypeFor` as a static method so this test does not need a real image.

---

### Task 4: Parser for Gemini JSON (no Firebase)

**Files:**
- Create: `lib/data/services/gemini_highlight_parser.dart`
- Test: `test/data/services/gemini_highlight_parser_test.dart`

**Interfaces:**
- Consumes: `Highlight` / `HighlightResponse` from Task 2
- Produces: `GeminiHighlightParser.parse(String? raw) → HighlightResponse`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_parser.dart';

void main() {
  test('parses highlights with literal and contextual', () {
    const raw = '''
{
  "highlights": [
    {
      "text": "due diligence",
      "literal": "careful investigation before a decision",
      "contextual": "Here it means checking the company thoroughly before buying it.",
      "color": "0xFFE8C547"
    }
  ]
}
''';
    final result = GeminiHighlightParser.parse(raw);
    expect(result.found, isTrue);
    expect(result.highlights, hasLength(1));
    expect(result.highlights!.first.text, 'due diligence');
    expect(result.highlights!.first.literal, contains('investigation'));
    expect(result.highlights!.first.contextual, contains('company'));
    expect(result.highlights!.first.color, '0xFFE8C547');
  });

  test('empty highlights means not found', () {
    final result = GeminiHighlightParser.parse('{"highlights":[]}');
    expect(result.found, isFalse);
    expect(result.highlights, isEmpty);
  });

  test('null or invalid json means not found', () {
    expect(GeminiHighlightParser.parse(null).found, isFalse);
    expect(GeminiHighlightParser.parse('not-json').found, isFalse);
  });

  test('drops items with empty text', () {
    final result = GeminiHighlightParser.parse(
      '{"highlights":[{"text":"","literal":"x","contextual":"y"}]}',
    );
    expect(result.found, isFalse);
  });
}
```

- [ ] **Step 2: Run tests — expect fail**

```bash
flutter test test/data/services/gemini_highlight_parser_test.dart
```

- [ ] **Step 3: Implement parser**

```dart
import 'dart:convert';

import '../../domain/entities/highlight.dart';

class GeminiHighlightParser {
  static const defaultInk = '0xFFE8C547';
  static const defaultText = '0xFF1A1A1A';

  static HighlightResponse parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const HighlightResponse(found: false, highlights: []);
      }
      final items = decoded['highlights'];
      if (items is! List) {
        return const HighlightResponse(found: false, highlights: []);
      }
      final highlights = <Highlight>[];
      for (final item in items) {
        if (item is! Map) continue;
        final text = '${item['text'] ?? ''}'.trim();
        if (text.length < 2) continue;
        final literal = '${item['literal'] ?? ''}'.trim();
        final contextual = '${item['contextual'] ?? ''}'.trim();
        highlights.add(
          Highlight(
            text: text,
            literal: literal.isEmpty ? 'Meaning unavailable.' : literal,
            contextual: contextual,
            color: _color('${item['color'] ?? ''}'),
            textColor: defaultText,
          ),
        );
      }
      return HighlightResponse(
        found: highlights.isNotEmpty,
        highlights: highlights,
      );
    } catch (_) {
      return const HighlightResponse(found: false, highlights: []);
    }
  }

  static String _color(String raw) {
    final value = raw.trim();
    if (RegExp(r'^0x[0-9A-Fa-f]{8}$').hasMatch(value)) return value;
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return '0xFF${value.substring(1).toUpperCase()}';
    }
    return defaultInk;
  }
}
```

- [ ] **Step 4: Re-run tests — expect PASS**

---

### Task 5: Gemini client + scan facade

**Files:**
- Create: `lib/data/services/gemini_highlight_service.dart`
- Create: `lib/data/services/highlight_scan_service.dart`

**Interfaces:**
- Consumes: `PageImageCompressor`, `GeminiHighlightParser`, `AppConstants.geminiModelId`
- Produces:
  - `GeminiHighlightService.analyze(CompressedPageImage) → Future<HighlightResponse>`
  - `HighlightScanService.scan(File, {onStatus}) → Future<HighlightResponse>`
  - `HighlightScanException` with `userMessage`

- [ ] **Step 1: Implement Gemini service**

```dart
import 'package:firebase_ai/firebase_ai.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/highlight.dart';
import 'gemini_highlight_parser.dart';
import 'page_image_compressor.dart';

class GeminiHighlightService {
  GeminiHighlightService({GenerativeModel? model}) : _model = model ?? _createModel();

  final GenerativeModel _model;

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
    final response = await _model.generateContent([
      Content.multi([
        TextPart(
          'Extract every highlighted phrase from this page photo. '
          'Return JSON only.',
        ),
        InlineDataPart(image.mimeType, image.bytes),
      ]),
    ]);
    return GeminiHighlightParser.parse(response.text);
  }
}
```

If `generationConfig` / `ThinkingLevel.minimal` / `Content.system` names differ in the installed `firebase_ai` version, match the package API (`analyze_files` / read `package:firebase_ai`). Do not change the model id.

- [ ] **Step 2: Implement scan facade**

```dart
import 'dart:io';

import '../../domain/entities/highlight.dart';
import 'gemini_highlight_service.dart';
import 'page_image_compressor.dart';

class HighlightScanException implements Exception {
  HighlightScanException(this.userMessage, {this.cause});
  final String userMessage;
  final Object? cause;
  @override
  String toString() => userMessage;
}

class HighlightScanService {
  HighlightScanService({
    PageImageCompressor? compressor,
    GeminiHighlightService? gemini,
  })  : _compressor = compressor ?? const PageImageCompressor(),
        _gemini = gemini ?? GeminiHighlightService();

  final PageImageCompressor _compressor;
  final GeminiHighlightService _gemini;

  Future<HighlightResponse> scan(
    File imageFile, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Preparing photo');
    final compressed = await _compressor.compress(imageFile);

    onStatus?.call('Finding highlighted text');
    try {
      return await _gemini.analyze(compressed);
    } catch (e) {
      throw HighlightScanException(
        'Could not read the page. Check your internet connection and try again.',
        cause: e,
      );
    }
  }
}
```

Do not call Gemini when offline — `HomeScreen` gates that in Task 6.

---

### Task 6: Rewire HomeScreen, analytics, and offline behavior

**Files:**
- Modify: `lib/home_screen.dart`
- Modify: `lib/core/firebase/app_analytics.dart`
- Modify: `lib/presentation/widgets/home/image_capture_section.dart`

**Interfaces:**
- Consumes: `HighlightScanService.scan`
- Removes: `refreshMeanings`, `lookupMeanings`, `hadNetworkLookupFailure`, `_refreshPendingMeanings`

- [ ] **Step 1: Update analytics**

Change `logScanCompleted` to:

```dart
  static Future<void> logScanCompleted({
    required bool found,
    required int highlightCount,
    required bool offline,
  }) {
    return _logEvent(
      'scan_completed',
      {
        'found': found ? 1 : 0,
        'highlight_count': highlightCount,
        'offline': offline ? 1 : 0,
      },
    );
  }
```

Add `logScanFailed(reason: 'offline')` when the user tries to scan offline. Drop `dictionary_partial_failure`.

- [ ] **Step 2: Replace pipeline usage in `home_screen.dart`**

- Field: `final HighlightScanService _scan = HighlightScanService();`
- Delete `_isRefreshingMeanings`, `_refreshPendingMeanings`, and the “back online → load definitions” branch.
- On connectivity restore, only clear `_offline` and snackbar: `'Back online. You can scan a page now.'`
- Offline snackbar (listen + silent refresh): `'You are offline. Connect to the internet to scan a page.'`
- `_pickImage`: use picker size limits from Task 3. If `_offline`, snackbar and return **before** picking (or after pick, before `_processImage` — prefer before pick).
- `_processImage`: if offline, `logScanFailed(reason: 'offline')`, `_fail('Connect to the internet to scan a page.')`, return.
- Status strings: `'Preparing photo'` then `'Finding highlighted text'`.
- Catch `HighlightScanException` and show `e.userMessage`.
- Success snackbar: `'Enjoy the highlighted text. Tap a phrase for literal and in-context meaning.'`
- Empty result snackbar stays: `'No highlighted text found. Use a sharp photo of a book page with highlighter marks.'`
- Remove `lookupMeanings` Crashlytics key.

- [ ] **Step 3: Offline banner copy**

In `image_capture_section.dart` `_OfflineBanner`, change text to:

`Offline — connect to the internet to scan a page`

Disable Gallery/Camera when `offline || isProcessing` (pass through existing `onPressed: isProcessing ? null : ...` and also `offline`).

---

### Task 7: Show literal + contextual on the card; update onboarding

**Files:**
- Modify: `lib/presentation/widgets/highlight/expandable_highlight_card.dart`
- Modify: `lib/presentation/pages/onboarding/onboarding_page.dart`

- [ ] **Step 1: Card body when expanded**

Replace the single `SelectableText(highlight.literal)` with:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Literal', style: theme.textTheme.labelMedium),
    const SizedBox(height: 4),
    SelectableText(highlight.literal, style: theme.textTheme.bodyMedium),
    if (highlight.contextual.isNotEmpty) ...[
      const SizedBox(height: 12),
      Text('In this sentence', style: theme.textTheme.labelMedium),
      const SizedBox(height: 4),
      SelectableText(highlight.contextual, style: theme.textTheme.bodyMedium),
    ],
  ],
)
```

Keep tap-to-expand. Card hint stays `'Tap for meaning'` / `'Hide meaning'`.

In `home_screen.dart` the list subtitle (`'N highlights — tap to see meaning'`) becomes `'N highlights — tap for literal and in-context meaning'`.

- [ ] **Step 2: Onboarding page 3 body**

Replace the third page body with:

```
- Use a sharp, well-lit photo of the page.
- You need an internet connection to find highlights and meanings.
- If nothing is highlighted, you will not get a result.
- For each phrase you will get a short literal meaning and how it is used in the sentence.
```

Page 1/2 can stay. Do not rewrite onboarding assets.

---

### Task 8: Firebase bootstrap (App Check + anonymous Auth)

**Files:**
- Modify: `lib/core/firebase/firebase_bootstrap.dart`

- [ ] **Step 1: After `Firebase.initializeApp`**

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Anonymous auth failed: $e\n$st');
      }
      await _crashlytics?.recordError(e, st, fatal: false);
    }
```

Enable **Anonymous** sign-in in Firebase Console → Authentication if the call fails.

- [ ] **Step 2: Debug App Check tokens**

Run the app once. Copy the App Check debug token from Logcat / Xcode and add it under **Firebase Console → App Check → Manage debug tokens**. Without this, simulator/emulator calls fail after App Check is enforced.

- [ ] **Step 3: Rebuild native projects**

```bash
cd ios && pod install && cd ..
flutter clean
flutter pub get
flutter run
```

Expected: app launches; Firebase init does not throw.

---

### Task 9: Delete the old pipeline and unused constants

**Files:**
- Delete the six files listed in the file map
- Modify: `lib/core/constants/app_constants.dart` — remove `meaningPendingPlaceholder` and `meaningUnavailablePlaceholder` if unused
- Grep the repo for `TextProcessingPipeline`, `DictionaryMeaning`, `OpenCv`, `OcrService`, `HighlightExtractor`, `ExtractedPhrase`, `HighlightMask`, `lookup_meanings`, `meaningPending`

- [ ] **Step 1: Delete files**

```bash
rm lib/data/services/text_processing_pipeline.dart \
   lib/data/services/opencv_highlight_detector.dart \
   lib/data/services/ocr_service.dart \
   lib/data/services/highlight_extractor.dart \
   lib/data/services/dictionary_meaning_service.dart \
   lib/data/models/highlight_detection.dart
```

- [ ] **Step 2: Analyzer must be clean**

```bash
dart analyze lib test
flutter test
```

Expected: no errors. Warnings about unused imports must be fixed.

- [ ] **Step 3: Confirm pubspec no longer pulls OpenCV/ML Kit**

`pubspec.lock` should not list `opencv_dart`, `dartcv4`, `google_mlkit_text_recognition`, or `http` after `flutter pub get`. If `http` remains as a transitive dep of Firebase, that is fine — just no direct dependency.

---

### Task 10: Manual verification

- [ ] **Step 1: Offline**

Airplane mode → Gallery/Camera disabled or snackbar `'Connect to the internet to scan a page.'` No Gemini call.

- [ ] **Step 2: Online, no highlighter**

Plain printed page → snackbar no highlights; empty list.

- [ ] **Step 3: Online, highlighted phrases**

Book page with 2+ highlighter marks → cards show phrase; expand shows **Literal** and **In this sentence**. Ink stripe color roughly matches the marker when Gemini returns `color`.

- [ ] **Step 4: Blurry / dark photo**

User-facing error or empty result — no crash.

- [ ] **Step 5: Debug logs**

In debug, print `usageMetadata` (prompt / candidates / thoughts tokens) once per successful scan to confirm thinking is near zero and input tokens match a resized image (~1k image tokens, not ~6k). Remove or gate behind `kDebugMode`.

---

## Removal checklist (do not leave these)

| Remove | Why |
|---|---|
| OpenCV detector + `opencv_dart` + dartcv hooks | Highlight detection moves to Gemini |
| ML Kit `OcrService` | Gemini reads the photo |
| `HighlightExtractor` + `highlight_detection.dart` | No blob/word intersection |
| `DictionaryMeaningService` + Datamuse + Free Dictionary + direct `http` | Meanings come from Gemini |
| `TextProcessingPipeline` | Replaced by `HighlightScanService` |
| Offline extract + later `refreshMeanings` | Scan requires network |
| `dictionary_partial_failure` analytics | No dictionary |

## Cost reminder (do not implement billing UI)

Flash-Lite + resized image + minimal thinking ≈ **$0.002–$0.0035 / scan** paid, or **$0** on free tier until ~**500 RPD / 15 RPM** (verify in AI Studio). 100 scans ≈ **$0.20–$0.35** paid.

## Spec coverage

- Gemini-only detect + literal + contextual → Tasks 4–7
- Flash-Lite + minimal thinking + resize → Tasks 3, 5
- App Check / AI Logic enable → Tasks 1, 8
- Delete old pipeline → Task 9
- Offline requires internet → Task 6
- Card + onboarding copy → Task 7

## Type consistency

- `Highlight.contextual` is `String` (never null); empty string if model omits it.
- `HighlightScanService.scan(File, {onStatus})` is the only UI entry point.
- Analytics `logScanCompleted` has no `dictionaryPartialFailure`.
