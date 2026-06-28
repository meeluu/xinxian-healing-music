import 'package:flutter/foundation.dart';
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/pipeline/ports/cloud_feedback_uploader.dart';

/// Mock 云端反馈上传实现（测试用）。
///
/// - 内存态记录所有调用，便于测试断言
/// - 不实际发起 HTTP 请求
/// - 可配置是否"同意云端采集"以测试前置检查逻辑
class MockCloudFeedbackUploader implements CloudFeedbackUploader {
  /// 是否同意云端采集（前置检查）。
  final bool consentAccepted;

  /// 是否同意上传文字反馈。
  final bool textConsentAccepted;

  /// 所有 upload 调用的 payload 记录（按调用顺序）。
  final List<CloudFeedbackPayload> uploaded = [];

  /// 所有被剥离文字字段的 payload 记录（用于断言文字同意逻辑）。
  final List<CloudFeedbackPayload> uploadedWithoutText = [];

  MockCloudFeedbackUploader({
    this.consentAccepted = true,
    this.textConsentAccepted = false,
  });

  @override
  Future<void> upload(CloudFeedbackPayload payload) async {
    if (!consentAccepted) {
      debugPrint('[MockCloudUploader] skipped: consent not accepted');
      return;
    }

    if (textConsentAccepted) {
      uploaded.add(payload);
    } else {
      // 模拟剥离文字字段：用新 payload 替换 freeTextFeedback 为 null
      final stripped = CloudFeedbackPayload(
        sessionId: payload.sessionId,
        listeningSessionId: payload.listeningSessionId,
        createdAt: payload.createdAt,
        experimentVariant: payload.experimentVariant,
        analyzerMode: payload.analyzerMode,
        targetState: payload.targetState,
        emotionTags: payload.emotionTags,
        valence: payload.valence,
        arousal: payload.arousal,
        intensity: payload.intensity,
        musicTitle: payload.musicTitle,
        audioAssetId: payload.audioAssetId,
        audioAssetTitle: payload.audioAssetTitle,
        bpm: payload.bpm,
        brainwaveTarget: payload.brainwaveTarget,
        noiseLayer: payload.noiseLayer,
        relaxationScore: payload.relaxationScore,
        emotionMatchScore: payload.emotionMatchScore,
        calmnessScore: payload.calmnessScore,
        willingToContinue: payload.willingToContinue,
        freeTextFeedback: null,
        clientVersion: payload.clientVersion,
        userAgent: payload.userAgent,
        source: payload.source,
        schemaVersion: payload.schemaVersion,
      );
      uploaded.add(stripped);
      uploadedWithoutText.add(stripped);
    }
  }

  /// 调用次数。
  int get callCount => uploaded.length;

  /// 是否被调用过。
  bool get wasCalled => uploaded.isNotEmpty;

  /// 重置所有记录（测试间清理）。
  void reset() {
    uploaded.clear();
    uploadedWithoutText.clear();
  }
}
