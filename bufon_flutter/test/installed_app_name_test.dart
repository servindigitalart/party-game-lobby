// test/installed_app_name_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP16 — the name under the icon.
///
/// The app shipped as `bufon_flutter` on Android and `Bufon Flutter` on iOS:
/// the scaffolding defaults, never changed. `V1.1_GAP_ANALYSIS.md` lists it as
/// the reason testers could not find the app on their own phones.
///
/// These read the real platform configuration rather than a constant declared
/// nearby — a test that restates its own expectation would keep passing after
/// somebody regenerated the manifest. Same `File(...).readAsStringSync()`
/// shape the adoption invariants in `bufon_component_primitives_test` use.
void main() {
  const expected = 'Bufón';

  String read(String path) => File(path).readAsStringSync();

  group('installed app name', () {
    test('Android labels the application Bufón', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');

      // `android:label` on <application> is what the launcher draws. Matched
      // by its attribute rather than by a bare substring so a stray mention
      // of the word elsewhere in the manifest could not satisfy this.
      final label = RegExp(r'android:label="([^"]*)"').firstMatch(manifest);

      expect(label, isNotNull, reason: 'no android:label in the manifest');
      expect(label!.group(1), expected);
    });

    /// The value paired with [key] in the app's own Info.plist.
    ///
    /// `ios/Runner/Info.plist` is authoritative for the shipped app: the
    /// Runner target sets `INFOPLIST_FILE = Runner/Info.plist` in all three
    /// configurations. `GENERATE_INFOPLIST_FILE = YES` in the same project
    /// file belongs to RunnerTests, which is a different bundle.
    String? plistValue(String key) => RegExp(
      '<key>$key</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(read('ios/Runner/Info.plist'))?.group(1);

    test('iOS displays the app as Bufón', () {
      // CFBundleDisplayName is the home-screen label.
      final display = plistValue('CFBundleDisplayName');

      expect(display, isNotNull, reason: 'no CFBundleDisplayName in Info.plist');
      expect(display, expected);
    });

    test('the iOS short name matches the display name', () {
      // CFBundleName is the short name iOS falls back to where the display
      // name does not fit — Settings, storage listings. It is not an
      // identifier: CFBundleIdentifier is, and it stays
      // `\$(PRODUCT_BUNDLE_IDENTIFIER)`. Left at the scaffolding value it was
      // the one place a player could still be shown `bufon_flutter`.
      final name = plistValue('CFBundleName');

      expect(name, isNotNull, reason: 'no CFBundleName in Info.plist');
      expect(name, expected);
      // Apple caps this one at 15 characters, unlike the display name.
      expect(name!.length, lessThanOrEqualTo(15));
    });

    test('the bundle identifier is still a build variable, not a name', () {
      // Guards the edit above from drifting into identity: whatever happens
      // to the two visible names, the identifier stays what Xcode injects.
      expect(plistValue('CFBundleIdentifier'), r'$(PRODUCT_BUNDLE_IDENTIFIER)');
    });

    test('neither platform still carries a scaffolding name', () {
      // The specific regression this guards: `flutter create` writes the
      // package directory name into both files, and a regenerated platform
      // folder would silently put it back.
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final values = <String, String?>{
        'android:label': RegExp(
          r'android:label="([^"]*)"',
        ).firstMatch(manifest)?.group(1),
        'CFBundleDisplayName': plistValue('CFBundleDisplayName'),
        // Included deliberately: the secondary name is a place the
        // scaffolding string survived once already.
        'CFBundleName': plistValue('CFBundleName'),
      };

      for (final entry in values.entries) {
        expect(entry.value, isNot('bufon_flutter'), reason: entry.key);
        expect(entry.value, isNot('Bufon Flutter'), reason: entry.key);
      }
    });

    test('the debug and profile manifests do not override the label', () {
      // They merge over `main`. A label in either would win for that build
      // type and quietly diverge from the released name.
      for (final path in const [
        'android/app/src/debug/AndroidManifest.xml',
        'android/app/src/profile/AndroidManifest.xml',
      ]) {
        expect(read(path), isNot(contains('android:label')), reason: path);
      }
    });
  });
}
