import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

/// 云端反馈采集同意状态（M7 新增）。
enum CloudFeedbackConsentStatus {
  /// 未决定（首次启动 / 未弹过弹窗）。
  unknown,

  /// 已同意匿名云端采集。
  accepted,

  /// 已拒绝，反馈仅保存在本设备。
  declined,
}

/// 云端反馈采集同意状态持久化服务。
///
/// 镜像 [LlmConsentService] 的实现范式：
/// - key: `xinxian.cloud.feedback.consent`
/// - value: 'unknown' / 'accepted' / 'declined'
///
/// 仅保存用户选择，不保存任何反馈内容或会话数据。
/// 底层存储由 [PreferencesPort] 抽象，Web 端 SharedPreferences 失败时
/// 自动 fallback 到 window.localStorage。
class CloudFeedbackConsentService {
  static const String key = 'xinxian.cloud.feedback.consent';

  final PreferencesPort _prefs;
  CloudFeedbackConsentStatus _status;

  CloudFeedbackConsentService._(this._prefs, this._status);

  /// 从磁盘加载当前同意状态；损坏/缺失时回退 [CloudFeedbackConsentStatus.unknown]。
  static Future<CloudFeedbackConsentService> create(
    PreferencesPort prefs,
  ) async {
    CloudFeedbackConsentStatus status;
    try {
      final raw = prefs.getString(key);
      status = _parse(raw);
    } catch (_) {
      status = CloudFeedbackConsentStatus.unknown;
    }
    return CloudFeedbackConsentService._(prefs, status);
  }

  CloudFeedbackConsentStatus get status => _status;

  /// 是否已同意云端采集。
  bool get isAccepted => _status == CloudFeedbackConsentStatus.accepted;

  /// 是否需要弹出首次同意弹窗。
  bool get needsPrompt => _status == CloudFeedbackConsentStatus.unknown;

  /// 更新同意状态并持久化。
  Future<void> setStatus(CloudFeedbackConsentStatus status) async {
    _status = status;
    try {
      await _prefs.setString(key, status.name);
    } catch (_) {
      // 持久化失败不影响当前会话使用（内存态已更新）
    }
  }

  static CloudFeedbackConsentStatus _parse(String? raw) {
    switch (raw) {
      case 'accepted':
        return CloudFeedbackConsentStatus.accepted;
      case 'declined':
        return CloudFeedbackConsentStatus.declined;
      default:
        return CloudFeedbackConsentStatus.unknown;
    }
  }
}
