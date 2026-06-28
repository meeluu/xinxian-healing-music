import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/ports/cloud_feedback_uploader.dart';

/// 生产环境云端反馈上传实现：调用同域 `/api/submit-feedback`。
///
/// 语义：fire-and-forget。
/// - 未同意云端采集 → 静默跳过
/// - 未同意文字上传 → 剥离 `freeTextFeedback` 字段
/// - 网络失败 / 超时 / 非 200 / ok:false → debugPrint 日志，不抛异常
/// - 任何异常都不影响调用方（本地反馈已保存）
///
/// 与 [LlmMoodAnalyzer] 的 HTTP 调用风格一致：
/// - `Uri.base.resolve('/api/submit-feedback')` 同域调用
/// - 6 秒超时（反馈上传对实时性要求低，可短一些）
/// - 不关心响应内容（fire-and-forget）
class HttpCloudFeedbackUploader implements CloudFeedbackUploader {
  final CloudFeedbackConsentService _consent;
  final CloudTextConsentService _textConsent;
  final http.Client _client;

  // 保持命名参数公开（consent / textConsent），便于测试文件注入 mock client。
  // ignore: prefer_initializing_formals
  HttpCloudFeedbackUploader({
    required CloudFeedbackConsentService consent,
    required CloudTextConsentService textConsent,
    http.Client? client,
  }) : _consent = consent, // ignore: prefer_initializing_formals
       _textConsent = textConsent, // ignore: prefer_initializing_formals
       _client = client ?? http.Client();

  /// 解析接口的完整 URL（同域）。
  Uri _endpoint() => Uri.base.resolve('/api/submit-feedback');

  @override
  Future<void> upload(CloudFeedbackPayload payload) async {
    // 同意前置检查：未同意云端采集 → 静默跳过
    if (!_consent.isAccepted) {
      debugPrint('[M7] cloud upload skipped: consent not accepted');
      return;
    }

    // 文字反馈独立同意：未同意则剥离 freeTextFeedback
    Map<String, dynamic> json;
    if (_textConsent.isAccepted) {
      json = payload.toJson();
    } else {
      // 复制后剥离文字字段
      json = Map<String, dynamic>.from(payload.toJson());
      json.remove('freeTextFeedback');
    }

    try {
      final resp = await _client
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(json),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) {
        debugPrint('[M7] cloud upload http_${resp.statusCode}');
        return;
      }

      // 解析响应确认（仅日志，不影响流程）
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          debugPrint('[M7] cloud upload ok: ${payload.listeningSessionId}');
        } else {
          debugPrint(
            '[M7] cloud upload backend returned ok=false: '
            'reason=${body['reason'] ?? "unknown"}',
          );
        }
      } catch (_) {
        // 响应不是 JSON 也不影响（fire-and-forget）
        debugPrint('[M7] cloud upload response not json');
      }
    } catch (e) {
      // 网络错误 / 超时 / CORS 等 —— 静默吞掉，不影响用户
      debugPrint('[M7] cloud upload failed: $e');
    }
  }
}
