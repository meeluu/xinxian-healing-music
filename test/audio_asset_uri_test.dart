import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/utils/audio_asset_uri.dart';

/// AudioAssetUriResolver 测试。
///
/// 测试分两组：
/// - 非 Web 平台：`flutter test`（VM）下运行，验证保留 asset key
/// - Web 平台：`flutter test -p chrome` 下运行，验证解析为 `assets/<key>`
///
/// `kIsWeb` 是编译时常量，无法在运行时切换，因此两组测试通过 skip 互斥。
void main() {
  group('AudioAssetUriResolver - 通用行为（所有平台）', () {
    test(
      'defaultAssetKey 为 music/sleep_01.mp3（与 AudioAssetCatalog.fallback 一致）',
      () {
        expect(AudioAssetUriResolver.defaultAssetKey, 'music/sleep_01.mp3');
      },
    );

    test('空 assetKey fallback 到默认音频', () {
      final desc = AudioAssetUriResolver.describe('');
      expect(desc.assetKey, AudioAssetUriResolver.defaultAssetKey);
      expect(desc.assetKey, 'music/sleep_01.mp3');
    });

    test('非空 assetKey 原样保留', () {
      final desc = AudioAssetUriResolver.describe('music/energize_01.mp3');
      expect(desc.assetKey, 'music/energize_01.mp3');
    });
  });

  group('AudioAssetUriResolver - 非 Web 平台（VM / 移动端）', () {
    // kIsWeb=true 时跳过本组（在 chrome 测试下）
    final skipReason = kIsWeb ? '仅非 Web 平台' : null;

    test('useAssetSource=true（走 AudioSource.asset）', skip: skipReason, () {
      final desc = AudioAssetUriResolver.describe('music/sleep_01.mp3');
      expect(desc.useAssetSource, isTrue);
    });

    test('webUrl 为 null', skip: skipReason, () {
      final desc = AudioAssetUriResolver.describe('music/sleep_01.mp3');
      expect(desc.webUrl, isNull);
    });

    test('assetKey 保留为 Flutter asset key（不带 assets/ 前缀）', skip: skipReason, () {
      final desc = AudioAssetUriResolver.describe('music/regulate_01.mp3');
      expect(desc.assetKey, 'music/regulate_01.mp3');
      expect(desc.assetKey, isNot(startsWith('assets/')));
    });

    test('resolveAudioSource 不抛异常', skip: skipReason, () {
      // 非 Web 下应返回 AudioSource.asset 实例
      final source = AudioAssetUriResolver.resolveAudioSource(
        'music/sleep_01.mp3',
      );
      expect(source, isNotNull);
    });
  });

  group('AudioAssetUriResolver - Web 平台', () {
    // kIsWeb=false 时跳过本组（在 VM 测试下）
    // 需用 `flutter test -p chrome test/audio_asset_uri_test.dart` 运行
    final skipReason = kIsWeb ? null : '仅 Web 平台（用 flutter test -p chrome 运行）';

    test('sleep_01 在 Web 下解析为 assets/music/sleep_01.mp3', skip: skipReason, () {
      final desc = AudioAssetUriResolver.describe('music/sleep_01.mp3');
      expect(desc.useAssetSource, isFalse);
      expect(desc.webUrl, 'assets/music/sleep_01.mp3');
    });

    test(
      'regulate_01 在 Web 下解析为 assets/music/regulate_01.mp3',
      skip: skipReason,
      () {
        final desc = AudioAssetUriResolver.describe('music/regulate_01.mp3');
        expect(desc.useAssetSource, isFalse);
        expect(desc.webUrl, 'assets/music/regulate_01.mp3');
      },
    );

    test(
      'soothe_01 / focus_01 / energize_01 在 Web 下均带 assets/ 前缀',
      skip: skipReason,
      () {
        for (final key in [
          'music/soothe_01.mp3',
          'music/focus_01.mp3',
          'music/energize_01.mp3',
        ]) {
          final desc = AudioAssetUriResolver.describe(key);
          expect(desc.useAssetSource, isFalse, reason: key);
          expect(desc.webUrl, 'assets/$key', reason: key);
        }
      },
    );

    test(
      '空 assetKey 在 Web 下 fallback 到 assets/music/sleep_01.mp3',
      skip: skipReason,
      () {
        final desc = AudioAssetUriResolver.describe('');
        expect(desc.useAssetSource, isFalse);
        expect(desc.webUrl, 'assets/music/sleep_01.mp3');
      },
    );

    test('resolveAudioSource 不抛异常', skip: skipReason, () {
      final source = AudioAssetUriResolver.resolveAudioSource(
        'music/sleep_01.mp3',
      );
      expect(source, isNotNull);
    });
  });
}
