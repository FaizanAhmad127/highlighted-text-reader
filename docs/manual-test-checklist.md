# Manual test checklist

Run the same pass on **Android** and **iOS** unless a row is marked for one platform. Tick the platform columns as you go.

**Pass** = UI matches, logic matches, no crash, no `permission-denied` / unexpected snackbar.

Copy below is the exact string the app shows.

| Prep | Android | iOS |
| --- | --- | --- |
| Fresh install (or clear app data) for first-launch cases | | |
| Returning-user install (onboarding already completed) | | |
| Two phones for QR (A shares, B imports). Same or mixed OS is fine | | |
| One sharp photo of a book page with highlighter marks | | |
| One photo with **no** highlighted text | | |
| Airplane mode / Wi‑Fi off ready | | |
| Know how to open app Settings (camera / photos) | | |

---

## 1. Onboarding (first launch only)

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 1.1 | Cold start after fresh install | Three pages: **Highlight it**, **Take/upload picture**, **Now wait while we process the image**. Images load. Skip / Back / Next / Done visible | | |
| 1.2 | Swipe and use Back / Next | Pages move; Back works from page 2+ | | |
| 1.3 | Tap **Skip** on page 1 | Goes to home. Title **Highlighted Text Reader** | | |
| 1.4 | Fresh install again, finish with **Done** on last page | Goes to home | | |
| 1.5 | Kill app, relaunch | Onboarding does **not** show again | | |
| 1.6 | Rotate during onboarding | Layout stays usable; images not cropped into unreadability | | |

---

## 2. Home UI

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 2.1 | Land on home | App bar: title left-aligned. Translate icon (tooltip **Meaning language**). Bookmarks icon (tooltip **Saved highlights**). **Gallery** and **Camera** buttons | | |
| 2.2 | Quota ready | Label like `0 of 20 scans today` (max may differ if Firestore `settings/scan_limits` or a user override is set) | | |
| 2.3 | Brief first load | **Please wait, loading assets** can appear; Gallery/Camera disabled until quota is ready. Banner goes away | | |
| 2.4 | Gallery/Camera while quota still loading | Buttons disabled; no picker | | |
| 2.5 | Tap bookmarks | **Saved highlights**. Empty: **No saved highlights yet** / **Save phrases from a scan to see them here.** | | |
| 2.6 | Back from Saved | Home unchanged | | |
| 2.7 | Status bar / notch / home indicator | Content not under the system UI | | |
| 2.8 | Landscape after a successful scan | Swipe the list up: photo, Gallery/Camera, quota, and **Save all** slide away. List meets the app bar, then cards scroll. Swipe down at the top of the list: capture block returns | | |

---

## 3. Permissions

Photo and QR must **not** reuse each other’s copy.

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 3.1 | Camera: **deny** then tap **Camera** on home | Snackbar **Camera access is off. Enable it to take a photo.** Action **Open Settings** | | |
| 3.2 | Tap **Open Settings** | System settings for this app | | |
| 3.3 | Enable camera, return, tap **Camera** again | Camera opens (may prompt once more on iOS) | | |
| 3.4 | iOS only: first **Gallery** | Photos permission: *This app requires photo library access to photos to process and give you the best results on your highlighted text.* Allow → picker. Deny → cannot pick | | |
| 3.5 | Android only: first **Gallery** | System photo/files picker. If a permission sheet appears, Allow works; Deny does not crash | | |
| 3.6 | Saved → **Import via QR**, deny camera | **Camera access is off. Enable it to scan a QR code.** + **Open Settings**. Must **not** say “take a photo” | | |
| 3.7 | Allow camera, Import via QR | Scanner title **Scan highlight QR**. Preview, not a black screen | | |

---

## 4. Scan — happy path

Do Gallery and Camera separately.

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 4.1 | Online, pick highlighted page from **Gallery** | Status **Finding highlighted text**. Then list of phrases. Header `{N} highlights — tap for literal and in-context meaning`. Snackbar **Enjoy the highlighted text. Tap a phrase for literal and in-context meaning.** Quota increments by 1 | | |
| 4.2 | Same with **Camera** (take a page photo) | Same as 4.1 | | |
| 4.3 | Preview after a hit | Photo shrinks (compact). Tap preview → full screen **Page photo**, pinch-zoom, **Close** | | |
| 4.4 | Tap a card | **Hide meaning**. **Literal** (selectable). **In this sentence** if contextual text exists. Color bar matches highlighter. Only one card expanded | | |
| 4.5 | Tap again | Collapses to **Tap for meaning** | | |
| 4.6 | Translate icon during a scan | Disabled until scan finishes | | |
| 4.7 | Gallery/Camera during a scan | Disabled | | |

---

## 5. Scan — errors and limits

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 5.1 | Open picker, cancel | **No image selected, try again**. Quota unchanged | | |
| 5.2 | Photo with **no** highlights | **No highlighted text found. Use a sharp photo of a book page with highlighter marks.** | | |
| 5.3 | Blurry / dark / not a page | **We could not read this photo. Try a clear shot of one page with highlighted text.** or **Could not process the image. Try a clear photo of a book page with highlighted text.** No crash | | |
| 5.4 | Second scan within ~8 seconds | **Wait a few seconds before scanning again.** Quota unchanged | | |
| 5.5 | Wait ~8s, scan again | Allowed; quota +1 | | |
| 5.6 | Hit daily cap (`N of N scans today`, default 20) | Gallery/Camera blocked. **You've reached today's scan limit. Try again tomorrow.** Count label turns error-colored. **Request extra** visible | | |
| 5.7 | **Request extra** | Dialog **Want extra scans today?** Body about Mail. **Not now** dismisses. **Request extra scans** opens Mail (or copy fallback) | | |
| 5.8 | **Not now** | Dialog closes; still at limit | | |
| 5.9 | **Request extra scans** with Mail installed | Prefill to `khattakandcopk@gmail.com`. After send: **Send the email to finish your extra-scan request.** | | |
| 5.10 | No Mail app (or send cancelled) | **Could not open Mail. Support ID copied. Send it to khattakandcopk@gmail.com.** or **Could not start the request. Please try again later.** | | |
| 5.11 | Airplane mode, tap Gallery/Camera | Offline banner. Buttons disabled. **You are offline. Connect to the internet to scan a page.** | | |
| 5.12 | Come back online | **Back online. You can scan a page now.** Buttons enabled | | |
| 5.13 | Logs after a failed Gemini/Firebase AI call | User-facing snackbar, not a raw SDK stack. App stays on home | | |

---

## 6. Meaning language

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 6.1 | Tap translate | Sheet **Meaning language**. Subtitle **Used on the next scan. Highlighted phrases stay as they are.** Default **English**. **Same as highlighted text** near the top | | |
| 6.2 | Search e.g. `ur` / `Urdu` | List filters. Clear search restores list | | |
| 6.3 | Pick **Urdu**, dismiss | **Meanings will use Urdu on the next scan.** Current cards do **not** rewrite | | |
| 6.4 | Scan again | New literal/contextual in Urdu (or chosen language) | | |
| 6.5 | Pick **Same as highlighted text**, scan | Meanings match the page language | | |
| 6.6 | Kill app, relaunch, open sheet | Last choice still selected | | |

---

## 7. Save / unsave (home)

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 7.1 | Bookmark on one card | Filled bookmark. **Saved to your library.** Appears on Saved | | |
| 7.2 | Bookmark again | Outline bookmark. **Removed from your library.** Gone from Saved | | |
| 7.3 | **Save all** with unsaved cards | **Saved N highlights.** (or **Saved 1 highlight.**). Button becomes **All saved** and disables | | |
| 7.4 | **Save all** when everything is saved | Disabled **All saved**. If triggered: **All highlights are already saved.** | | |
| 7.5 | Save the same phrase twice (same language) | **Already saved.** No duplicate row on Saved | | |
| 7.6 | Save while **offline** | **Saved on this device. It will sync when you're back online.** Visible on Saved immediately | | |
| 7.7 | Go online | Item remains; no duplicate after sync | | |
| 7.8 | Two phrases from one scan, both saved | Saved groups them: **2 from this scan** | | |

---

## 8. Saved highlights

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 8.1 | Open with items | App bar **Saved highlights**. Search **Search highlighted phrases**. Date chips: **All**, **Today**, **This week**, **This month**, **Custom**. Language chips if more than one language exists (**All** + names) | | |
| 8.2 | First visit with items (this install) | First card briefly hints swipe-to-delete (red delete). Hint plays **once** | | |
| 8.3 | Swipe right-to-left on a card | Deletes. Item gone. Relaunch: still gone | | |
| 8.4 | Expand a saved card | Meaning + time caption (e.g. `3:05 PM`). No save bookmark on this page | | |
| 8.5 | Search a known phrase | Only matches. Clear (X) restores list | | |
| 8.6 | Search with no hits | **No highlights match these filters** / **Try a different search, date, or language.** | | |
| 8.7 | **Today** / **This week** / **This month** | List matches the chip. Selected chip moves to the front of the row | | |
| 8.8 | **Custom** | Date picker, last date = today. Pick a day with saves → only that day. Cancel → no change | | |
| 8.9 | Language chip | Filters to that meaning language. **All** restores | | |
| 8.10 | Day headers | **Today**, **Yesterday**, or `Mon D, YYYY` | | |
| 8.11 | Transfer menu | Overflow **Transfer highlights**: **Share via QR**, **Import via QR** | | |
| 8.12 | Share with empty library | **Share via QR** disabled | | |
| 8.13 | Landscape with saved items | Swipe the list up: search and date/language chips slide away. List meets the app bar, then cards scroll. Swipe down at the top: search and filters return. Empty/no-match states keep search and filters on screen | | |

---

## 9. QR transfer (two phones)

Use Phone A (library) and Phone B (empty or different library). Stay online and signed in (anonymous auth is automatic).

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 9.1 | A: **Share via QR** with items | Dialog **Share saved highlights**. QR ~220px. **Scan this code on the other phone. Valid for 30 minutes.** **Done** | | |
| 9.2 | Logs / Firestore | No `permission-denied`. Document `highlight_transfers/{A's uid}` plus `items` matching the library. Parent has `itemIds` | | |
| 9.3 | B: **Import via QR**, scan A’s code | **Added N highlights.** (or **Added 1 highlight.**). Items appear with meanings | | |
| 9.4 | B imports the same QR again | **Already saved.** or **All N were already saved.** No duplicates | | |
| 9.5 | A deletes one saved item, Shares again | B importing a **new** scan of the new QR must not re-add the deleted phrase as a new row on A. A’s Firestore `items` no longer includes the deleted id | | |
| 9.6 | B already has some of A’s phrases | Only new ones added; snackbar counts added, not skipped | | |
| 9.7 | Share again on A (overwrite) | Same QR (`htr1:{uid}`). New 30-minute window. Old leftover item docs removed | | |
| 9.8 | Airplane mode, Share or Import | **Connect to the internet to transfer highlights.** | | |
| 9.9 | Import a non-app QR (or random barcode) | Scanner ignores it (stays open) or **That QR code is not a highlight transfer.** | | |
| 9.10 | Import after waiting 30+ minutes without a new Share | **That QR code has expired.** | | |
| 9.11 | Share with empty list (if forced) | **Save a highlight before sharing.** | | |
| 9.12 | Create-share failure | **Could not create a share code.** App does not freeze | | |
| 9.13 | Import failure | **Could not import highlights.** or **That QR code was not found.** | | |
| 9.14 | Mixed OS: Android QR → iPhone and reverse | Both import | | |
| 9.15 | Background the scanner, return | Camera still works or a clear retry; no freeze | | |

---

## 10. Resilience and platform polish

| # | What to do | Expected | Android | iOS |
| --- | --- | --- | --- | --- |
| 10.1 | Background mid-scan, return | Finishes or shows a snackbar; no stuck spinner forever | | |
| 10.2 | Open Saved while a scan is running, then back | Scan still completes or fails cleanly | | |
| 10.3 | Rotate home (list + preview) and Saved (chips + list) | No overflow; chips still scroll. In landscape, lists can collapse headers as in 2.8 and 8.13 | | |
| 10.4 | Kill and relaunch after saves | Library intact (online: Firestore; offline: local then sync) | | |
| 10.5 | Snackbar visible, navigate away | No crash | | |
| 10.6 | Rapid double-tap Gallery / Share / Save | One picker / one QR / one save; no duplicate storms | | |
| 10.7 | Android back vs iOS swipe-back from Saved and QR scanner | Pops to the previous screen | | |
| 10.8 | Large library (~20+ saved, 10+ from one scan) | Scrolls smoothly; Share still works (no permission-denied) | | |
| 10.9 | Dark/light system theme if the OS forces it | Text still readable (app is a light Material theme) | | |
| 10.10 | Debug vs a release/profile build if you ship both | Same flows; iOS camera/photos still authorized | | |

---

## 11. Log red flags (either OS)

Fail the build if you see any of these during a normal pass:

- `PERMISSION_DENIED` / `Missing or insufficient permissions` on `highlight_transfers` or `saved_highlights`
- `Unhandled format for Content` from Firebase AI on a normal highlighted page (retry once; fail if repeated)
- Crashlytics fatal after a snackbar the user can already see
- Scanner or camera preview black after permission was granted
- Quota stuck on **Please wait, loading assets** for more than ~15s online

---

## Sign-off

| Platform | Build (debug / profile / release) | Tester | Date | Result |
| --- | --- | --- | --- | --- |
| Android | | | | Pass / Fail |
| iOS | | | | Pass / Fail |

Notes (device models, OS versions, quota override, failures):
