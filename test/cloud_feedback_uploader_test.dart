import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/pipeline/cloud/http_cloud_feedback_uploader.dart';
import 'package:xinxian_healing_music/pipeline/cloud/mock_cloud_feedback_uploader.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MockCloudFeedbackUploader', () {
    test('未同意云端采集时不调用 upload', () async {
      final uploader = MockCloudFeedbackUploader(
        consentAccepted: false,
        textConsentAccepted: false,
      );
      final payload = _buildPayload();

      await uploader.upload(payload);

      expect(uploader.callCount, 0);
      expect(uploader.wasCalled, isFalse);
    });

    test('同意云端采集但未同意文字 → upload 但剥离 freeTextFeedback', () async {
      final uploader = MockCloudFeedbackUploader(
        consentAccepted: true,
        textConsentAccepted: false,
      );
      final payload = _buildPayload(note: '我的文字反馈');

      await uploader.upload(payload);

      expect(uploader.callCount, 1);
      expect(uploader.uploadedWithoutText.length, 1);
      expect(uploader.uploaded.first.freeTextFeedback, isNull);
    });

    test('同意云端采集且同意文字 → upload 保留 freeTextFeedback', () async {
      final uploader = MockCloudFeedbackUploader(
        consentAccepted: true,
        textConsentAccepted: true,
      );
      final payload = _buildPayload(note: '我的文字反馈');

      await uploader.upload(payload);

      expect(uploader.callCount, 1);
      expect(uploader.uploadedWithoutText.length, 0);
      expect(uploader.uploaded.first.freeTextFeedback, '我的文字反馈');
    });

    test('reset 清空所有记录', () async {
      final uploader = MockCloudFeedbackUploader(
        consentAccepted: true,
        textConsentAccepted: true,
      );
      await uploader.upload(_buildPayload());
      expect(uploader.callCount, 1);

      uploader.reset();
      expect(uploader.callCount, 0);
      expect(uploader.wasCalled, isFalse);
    });
  });

  group('HttpCloudFeedbackUploader', () {
    test('未同意云端采集 → 不发起 HTTP 请求', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      // status 默认 unknown → isAccepted = false
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient();
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      await uploader.upload(_buildPayload(note: 'test'));

      expect(client.callCount, 0);
    });

    test('declined 状态 → 不发起 HTTP 请求', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.declined);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient();
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      await uploader.upload(_buildPayload());

      expect(client.callCount, 0);
    });

    test('同意云端采集 + 同意文字 → POST 包含 freeTextFeedback', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await textConsent.setStatus(CloudTextConsentStatus.accepted);

      String? capturedBody;
      final client = _FakeHttpClient((request) async {
        capturedBody = (request as http.Request).body;
        return _jsonResponse(200, {'ok': true, 'received': true});
      });
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      await uploader.upload(_buildPayload(note: '我的文字反馈'));

      expect(client.callCount, 1);
      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['freeTextFeedback'], '我的文字反馈');
      expect(body['listeningSessionId'], isNotNull);
    });

    test('同意云端采集但未同意文字 → POST 不包含 freeTextFeedback', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      // textConsent 默认 unknown → isAccepted = false

      String? capturedBody;
      final client = _FakeHttpClient((request) async {
        capturedBody = (request as http.Request).body;
        return _jsonResponse(200, {'ok': true, 'received': true});
      });
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      await uploader.upload(_buildPayload(note: '不应上传的文字'));

      expect(client.callCount, 1);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      // freeTextFeedback 应被剥离
      expect(body.containsKey('freeTextFeedback'), isFalse);
    });

    test('HTTP 非 200 状态码 → 不抛异常', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient(
        (_) async => _jsonResponse(500, {'error': 'internal'}),
      );
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      // 不应抛异常
      await uploader.upload(_buildPayload());
      expect(client.callCount, 1);
    });

    test('HTTP 异常（网络错误/超时）→ 不抛异常', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient(
        (_) async => throw Exception('network_timeout'),
      );
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      // 不应抛异常（fire-and-forget，内部 catch）
      await uploader.upload(_buildPayload());
      expect(client.callCount, 1);
    });

    test('响应 body 不是 JSON → 不抛异常', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient(
        (_) async =>
            http.StreamedResponse(Stream.value(utf8.encode('not json')), 200),
      );
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      // 不应抛异常
      await uploader.upload(_buildPayload());
      expect(client.callCount, 1);
    });

    test('后端返回 ok:false → 不抛异常', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await CloudFeedbackConsentService.create(
        SharedPrefsAdapter(prefs),
      );
      await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      final textConsent = await CloudTextConsentService.create(
        SharedPrefsAdapter(prefs),
      );

      final client = _FakeHttpClient(
        (_) async => _jsonResponse(200, {'ok': false, 'reason': 'db_error'}),
      );
      final uploader = HttpCloudFeedbackUploader(
        consent: consent,
        textConsent: textConsent,
        client: client,
      );

      // 不应抛异常
      await uploader.upload(_buildPayload());
      expect(client.callCount, 1);
    });
  });
}

// ─── 测试辅助 ──────────────────────────────────────────────────

CloudFeedbackPayload _buildPayload({String? note}) {
  // 同步构造 payload（不依赖 async mockPipeline）
  return CloudFeedbackPayload(
    sessionId: 'test-session-1',
    listeningSessionId: 'test-session-1',
    createdAt: DateTime(2026, 6, 28, 10, 0, 0).toIso8601String(),
    experimentVariant: 'custom',
    analyzerMode: 'mock',
    targetState: 'sleep',
    emotionTags: const ['焦虑', '紧绷'],
    valence: -0.4,
    arousal: 0.8,
    intensity: 0.7,
    musicTitle: '睡前舒缓 · Theta 入眠方案',
    audioAssetId: 'sleep_01.mp3',
    audioAssetTitle: '夜色舒缓',
    bpm: 60,
    brainwaveTarget: 'Theta 入眠',
    noiseLayer: '粉噪',
    relaxationScore: 4,
    emotionMatchScore: null,
    calmnessScore: 70,
    willingToContinue: null,
    freeTextFeedback: note,
    clientVersion: 'v0.7.0',
    userAgent: 'TestUA/1.0',
    source: 'web',
    schemaVersion: 1,
  );
}

/// 可控的 fake http.Client：记录调用次数，按 handler 返回响应。
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient([this._handler]);

  final Future<http.StreamedResponse> Function(http.BaseRequest)? _handler;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final handler = _handler;
    if (handler != null) {
      return handler(request);
    }
    return _jsonResponse(200, {'ok': true, 'received': true});
  }
}

/// 构造 JSON StreamedResponse。
http.StreamedResponse _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
