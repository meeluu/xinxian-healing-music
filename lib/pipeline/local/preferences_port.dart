import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储抽象接口。
///
/// 项目中 [LocalListeningSessionRecorder] / [LocalFeedbackRepository] /
/// [LlmConsentService] 三个本地持久化类原本直接依赖 [SharedPreferences]。
/// 但在 Flutter Web 上，[SharedPreferences] 依赖插件 method channel
/// (`plugins.flutter.io/shared_preferences`)，一旦插件未注册（Service Worker
/// 缓存旧版本 / Flutter SDK 与 shared_preferences 版本不兼容 / 某些浏览器
/// 隐私模式禁用 localStorage 插件层），就会抛
/// `MissingPluginException(No implementation found for method getAll ...)`。
///
/// 为保证 Web 端历史记录和 LLM 同意状态不因插件失败而彻底不可用，
/// 抽象出此接口，并提供两个实现：
/// - [SharedPrefsAdapter]：包装 [SharedPreferences]，正常路径使用
/// - [WebLocalStoragePrefs]：直接用 `dart:html` 的 `window.localStorage`，
///   在 Web 平台 [SharedPreferences] 失败时作为 fallback
///
/// 三个 Local 类的 `create` 方法改为接受 [PreferencesPort] 而非
/// [SharedPreferences]，从而可在运行时切换底层存储实现。
abstract class PreferencesPort {
  /// 读取字符串值；不存在时返回 null。
  String? getString(String key);

  /// 写入字符串值；返回是否成功。
  Future<bool> setString(String key, String value);

  /// 删除指定 key；返回是否成功。
  Future<bool> remove(String key);
}

/// 用 [SharedPreferences] 实现的 [PreferencesPort] 适配器。
///
/// [SharedPreferences] 本身已有 `getString` / `setString` / `remove` 方法，
/// 但未显式 `implements PreferencesPort`，所以需要此 adapter 完成类型适配。
class SharedPrefsAdapter implements PreferencesPort {
  final SharedPreferences _prefs;

  SharedPrefsAdapter(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);
}
