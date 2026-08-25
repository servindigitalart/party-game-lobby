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

    test('iOS displays the app as Bufón', () {
      final plist = read('ios/Runner/Info.plist');

      // CFBundleDisplayName is the home-screen label. Its value is the next
      // <string> after the key, which is how a plist pairs them.
      final display = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist);

      expect(
        display,
        isNotNull,
        reason: 'no CFBundleDisplayName in Info.plist',
      );
      expect(display!.group(1), expected);
    });

    test('neither platform still carries a scaffolding name', () {
      // The specific regression this guards: `flutter create` writes the
      // package directory name into both files, and a regenerated platform
      // folder would silently put it back.
      for (final path in const [
        'android/app/src/main/AndroidManifest.xml',
        'ios/Runner/Info.plist',
      ]) {
        final src = read(path);
        final label = RegExp(
          r'android:label="([^"]*)"|<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
        ).firstMatch(src);
        final value = label?.group(1) ?? label?.group(2);

        expect(value, isNot('bufon_flutter'), reason: path);
        expect(value, isNot('Bufon Flutter'), reason: path);
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
