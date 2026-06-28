import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudFeedbackConsentService', () {
    test('默认状态为 unknown', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent.status, CloudFeedbackConsentStatus.unknown);
      expect(consent.isAccepted, isFalse);
      expect(consent.needsPrompt, isTrue);
    });

    test('切换到 accepted 后持久化 + 重启保留', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent1 = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent1.setStatus(CloudFeedbackConsentStatus.accepted);
      expect(prefs.getString(CloudFeedbackConsentService.key), 'accepted');
      expect(consent1.isAccepted, isTrue);
      expect(consent1.needsPrompt, isFalse);

      // 模拟重启
      final consent2 = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent2.status, CloudFeedbackConsentStatus.accepted);
      expect(consent2.isAccepted, isTrue);
      expect(consent2.needsPrompt, isFalse);
    });

    test('切换到 declined 后持久化 + 重启保留', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent1 = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent1.setStatus(CloudFeedbackConsentStatus.declined);
      expect(prefs.getString(CloudFeedbackConsentService.key), 'declined');

      final consent2 = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent2.status, CloudFeedbackConsentStatus.declined);
      expect(consent2.isAccepted, isFalse);
      expect(consent2.needsPrompt, isFalse);
    });

    test('unknown 状态 needsPrompt 为 true', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent.status, CloudFeedbackConsentStatus.unknown);
      expect(consent.needsPrompt, isTrue);
      expect(consent.isAccepted, isFalse);
    });

    test('损坏的存储值回退 unknown', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CloudFeedbackConsentService.key,
        'garbage_value',
      );
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent.status, CloudFeedbackConsentStatus.unknown);
      expect(consent.needsPrompt, isTrue);
    });

    test('多次切换状态均持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      expect(
        (await CloudFeedbackConsentService.create(SharedPrefsAdapter(prefs)))
            .status,
        CloudFeedbackConsentStatus.accepted,
      );

      await consent.setStatus(CloudFeedbackConsentStatus.declined);
      expect(
        (await CloudFeedbackConsentService.create(SharedPrefsAdapter(prefs)))
            .status,
        CloudFeedbackConsentStatus.declined,
      );

      await consent.setStatus(CloudFeedbackConsentStatus.unknown);
      expect(
        (await CloudFeedbackConsentService.create(SharedPrefsAdapter(prefs)))
            .status,
        CloudFeedbackConsentStatus.unknown,
      );
    });
  });

  group('CloudTextConsentService', () {
    test('默认状态为 unknown，isAccepted 为 false（保守处理）', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent.status, CloudTextConsentStatus.unknown);
      // 关键：unknown 视为不同意（与 CloudFeedbackConsentService 不同）
      expect(consent.isAccepted, isFalse);
    });

    test('切换到 accepted 后持久化 + 重启保留', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent1 = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent1.setStatus(CloudTextConsentStatus.accepted);
      expect(prefs.getString(CloudTextConsentService.key), 'accepted');
      expect(consent1.isAccepted, isTrue);

      final consent2 = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent2.status, CloudTextConsentStatus.accepted);
      expect(consent2.isAccepted, isTrue);
    });

    test('切换到 declined 后持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudTextConsentStatus.declined);
      expect(consent.status, CloudTextConsentStatus.declined);
      expect(consent.isAccepted, isFalse);

      final consent2 = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent2.status, CloudTextConsentStatus.declined);
      expect(consent2.isAccepted, isFalse);
    });

    test('损坏的存储值回退 unknown（视为不同意）', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CloudTextConsentService.key, 'garbage');
      final consent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(consent.status, CloudTextConsentStatus.unknown);
      expect(consent.isAccepted, isFalse);
    });
  });

  group('key 隔离', () {
    test('两个 consent 服务使用不同 key，互不影响', () async {
      final prefs = await SharedPreferences.getInstance();
      final cloudConsent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      // 设置不同的状态
      await cloudConsent.setStatus(CloudFeedbackConsentStatus.accepted);
      await textConsent.setStatus(CloudTextConsentStatus.declined);

      // 验证 key 不同
      expect(CloudFeedbackConsentService.key, isNot(CloudTextConsentService.key));

      // 验证互不影响
      final cloudConsent2 = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      final textConsent2 = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      expect(cloudConsent2.status, CloudFeedbackConsentStatus.accepted);
      expect(textConsent2.status, CloudTextConsentStatus.declined);
      expect(cloudConsent2.isAccepted, isTrue);
      expect(textConsent2.isAccepted, isFalse);
    });

    test('与 LlmConsentService 的 key 也不同（防止冲突）', () async {
      // 仅验证 key 字面量不同
      expect(CloudFeedbackConsentService.key, 'xinxian.cloud.feedback.consent');
      expect(CloudTextConsentService.key, 'xinxian.cloud.feedback.text.consent');
      expect(
        CloudFeedbackConsentService.key,
        isNot('xinxian.llm.consent'),
      );
    });
  });

  group('PreferencesPort 抽象（fallback storage 兼容）', () {
    test('内存 Map storage 仍能保存 consent 且刷新后读回', () async {
      final fake = _FakePreferencesPort();
      final consent = await CloudFeedbackConsentService.create(fake);
      expect(consent.status, CloudFeedbackConsentStatus.unknown);

      await consent.setStatus(CloudFeedbackConsentStatus.accepted);

      // 模拟刷新
      final consent2 = await CloudFeedbackConsentService.create(fake);
      expect(consent2.status, CloudFeedbackConsentStatus.accepted);
      expect(consent2.isAccepted, isTrue);
    });

    test('损坏 JSON 不崩溃（getString 抛异常时回退 unknown）', () async {
      final fake = _ThrowingPreferencesPort();
      final consent = await CloudFeedbackConsentService.create(fake);
      expect(consent.status, CloudFeedbackConsentStatus.unknown);
      expect(consent.needsPrompt, isTrue);
    });
  });
}

/// 内存 Map 实现的 [PreferencesPort]，用于模拟 Web localStorage 行为。
class _FakePreferencesPort implements PreferencesPort {
  final Map<String, String> _store = {};

  @override
  String? getString(String key) => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }
}

/// getString 抛异常的 [PreferencesPort]，模拟存储损坏场景。
class _ThrowingPreferencesPort implements PreferencesPort {
  @override
  String? getString(String key) => throw Exception('storage_corrupted');

  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  Future<bool> remove(String key) async => false;
}
