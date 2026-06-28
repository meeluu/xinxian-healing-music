/// 条件导入入口：根据平台选择正确的 Web localStorage 实现。
///
/// - Web 平台（`dart.library.html` 可用）→ 导入 `web_preferences_factory_web.dart`
///   返回 [WebLocalStoragePrefs] 实例（直接用 `window.localStorage`）
/// - 非 Web 平台 → 导入 `web_preferences_factory_stub.dart` 抛 [UnsupportedError]
///
/// 用法（在 main.dart 中）：
/// ```dart
/// import 'package:xinxian_healing_music/pipeline/local/web_preferences_factory.dart';
///
/// if (kIsWeb) {
///   storage = createWebLocalStoragePrefs();
/// }
/// ```
library;

export 'web_preferences_factory_stub.dart'
    if (dart.library.html) 'web_preferences_factory_web.dart';
