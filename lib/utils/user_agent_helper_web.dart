// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// 此文件仅在 Web 平台通过条件导入被引用，必须使用 dart:html 访问 window.navigator。
import 'dart:html' show window;

/// Web 平台：返回 `window.navigator.userAgent`。
///
/// 用于云端反馈 payload 的 `userAgent` 字段，仅用于区分浏览器/设备类型，
/// 不用于追踪。读取失败时返回空字符串。
String getUserAgent() {
  try {
    return window.navigator.userAgent;
  } catch (_) {
    // 某些隐私模式或特殊浏览器可能禁用 navigator 访问
    return '';
  }
}
