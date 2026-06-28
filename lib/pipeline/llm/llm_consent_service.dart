import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

/// LLM 解析同意状态。
enum LlmConsentStatus {
  /// 未决定（首次启动 / 未弹过弹窗）。
  unknown,

  /// 已同意 AI 解析。
  accepted,

  /// 已拒绝，仅使用本地解析。
  declined,
}

/// LLM 同意状态持久化服务。
///
/// - key: `xinxian.llm.consent`
/// - value: 'unknown' / 'accepted' / 'declined'
///
/// 仅保存用户选择，不保存任何心境文本或解析结果。
/// 遵循项目 Local 实现范式：异步工厂 + 损坏回退 + fire-and-forget 持久化。
///
/// 底层存储由 [PreferencesPort] 抽象，正常运行时是 [SharedPrefsAdapter]
/// （包装 SharedPreferences），Web 端 SharedPreferences 插件失败时
/// 自动切换为 [WebLocalStoragePrefs]（直接用 window.localStorage）。
class LlmConsentService {
  static const String key = 'xinxian.llm.consent';

  final PreferencesPort _prefs;
  LlmConsentStatus _status;

  LlmConsentService._(this._prefs, this._status);

  /// 从磁盘加载当前同意状态；损坏/缺失时回退 [LlmConsentStatus.unknown]。
  static Future<LlmConsentService> create(PreferencesPort prefs) async {
    LlmConsentStatus status;
    try {
      final raw = prefs.getString(key);
      status = _parse(raw);
    } catch (_) {
      status = LlmConsentStatus.unknown;
    }
    return LlmConsentService._(prefs, status);
  }

  LlmConsentStatus get status => _status;

  /// 是否已同意 AI 解析。
  bool get isAccepted => _status == LlmConsentStatus.accepted;

  /// 是否需要弹出首次同意弹窗。
  bool get needsPrompt => _status == LlmConsentStatus.unknown;

  /// 更新同意状态并持久化。
  Future<void> setStatus(LlmConsentStatus status) async {
    _status = status;
    try {
      await _prefs.setString(key, status.name);
    } catch (_) {
      // 持久化失败不影响当前会话使用（内存态已更新）
    }
  }

  static LlmConsentStatus _parse(String? raw) {
    switch (raw) {
      case 'accepted':
        return LlmConsentStatus.accepted;
      case 'declined':
        return LlmConsentStatus.declined;
      default:
        return LlmConsentStatus.unknown;
    }
  }
}
