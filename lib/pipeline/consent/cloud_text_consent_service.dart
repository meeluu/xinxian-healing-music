import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

/// 云端文字反馈同意状态（M7 新增）。
///
/// 独立于 [CloudFeedbackConsentService]：
/// 即使同意云端采集，文字反馈默认也不上传，需单独勾选同意。
/// 这样设计是为了对文字内容做更保守的隐私保护（文字可能包含敏感个人信息）。
enum CloudTextConsentStatus {
  /// 未决定（默认视为不同意，保守处理）。
  unknown,

  /// 已同意上传文字反馈。
  accepted,

  /// 已拒绝上传文字反馈。
  declined,
}

/// 云端文字反馈同意状态持久化服务。
///
/// - key: `xinxian.cloud.feedback.text.consent`
/// - value: 'unknown' / 'accepted' / 'declined'
///
/// 默认行为：unknown 视为不同意（不上传文字），与 [CloudFeedbackConsentService]
/// 的 unknown 行为不同（后者 unknown 仅表示"未弹窗"，不阻塞云端采集本身）。
class CloudTextConsentService {
  static const String key = 'xinxian.cloud.feedback.text.consent';

  final PreferencesPort _prefs;
  CloudTextConsentStatus _status;

  CloudTextConsentService._(this._prefs, this._status);

  /// 从磁盘加载当前同意状态；损坏/缺失时回退 [CloudTextConsentStatus.unknown]。
  static Future<CloudTextConsentService> create(PreferencesPort prefs) async {
    CloudTextConsentStatus status;
    try {
      final raw = prefs.getString(key);
      status = _parse(raw);
    } catch (_) {
      status = CloudTextConsentStatus.unknown;
    }
    return CloudTextConsentService._(prefs, status);
  }

  CloudTextConsentStatus get status => _status;

  /// 是否已同意上传文字反馈。
  /// unknown 视为不同意（保守处理）。
  bool get isAccepted => _status == CloudTextConsentStatus.accepted;

  /// 更新同意状态并持久化。
  Future<void> setStatus(CloudTextConsentStatus status) async {
    _status = status;
    try {
      await _prefs.setString(key, status.name);
    } catch (_) {
      // 持久化失败不影响当前会话使用（内存态已更新）
    }
  }

  static CloudTextConsentStatus _parse(String? raw) {
    switch (raw) {
      case 'accepted':
        return CloudTextConsentStatus.accepted;
      case 'declined':
        return CloudTextConsentStatus.declined;
      default:
        return CloudTextConsentStatus.unknown;
    }
  }
}
