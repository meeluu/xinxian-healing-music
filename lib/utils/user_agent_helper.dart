/// 条件导入入口：根据平台选择正确的 userAgent 获取实现。
///
/// - Web 平台（`dart.library.html` 可用）→ 导入 `user_agent_helper_web.dart`
///   返回 `window.navigator.userAgent`
/// - 非 Web 平台 → 导入 `user_agent_helper_non_web.dart` 返回空字符串
///
/// 用法：
/// ```dart
/// import 'package:xinxian_healing_music/utils/user_agent_helper.dart';
///
/// final ua = getUserAgent();
/// ```
library;

export 'user_agent_helper_non_web.dart'
    if (dart.library.html) 'user_agent_helper_web.dart';
