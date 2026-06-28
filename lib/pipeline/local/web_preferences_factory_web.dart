// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// 此文件仅在 Web 平台通过条件导入被引用，必须使用 dart:html 访问 window.localStorage。
// dart:html 虽被标记为 deprecated（推荐 package:web + dart:js_interop），
// 但在 shared_preferences 插件失败的 fallback 场景下，dart:html 是最轻量、
// 最稳定的方案，且仅在 Web 平台编译。
import 'dart:html' show window;

import 'preferences_port.dart';

/// Web 平台的 [PreferencesPort] 实现：直接用 `window.localStorage`。
///
/// 当 Flutter Web 上 `SharedPreferences` 插件未注册（报
/// `MissingPluginException(getAll on channel plugins.flutter.io/shared_preferences)`）
/// 时作为 fallback，保证以下 key 能正常读写：
/// - `xinxian.sessions`
/// - `xinxian.feedback`
/// - `xinxian.llm.consent`
///
/// 与 `shared_preferences_web` 一样使用 `window.localStorage`，
/// 按 origin 隔离（不同子域名不共享）。
class WebLocalStoragePrefs implements PreferencesPort {
  WebLocalStoragePrefs();

  @override
  String? getString(String key) {
    try {
      return window.localStorage[key];
    } catch (_) {
      // 隐私模式 / localStorage 被禁用时返回 null
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      window.localStorage[key] = value;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      window.localStorage.remove(key);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Web 平台工厂：返回 [WebLocalStoragePrefs] 实例。
PreferencesPort createWebLocalStoragePrefs() => WebLocalStoragePrefs();
