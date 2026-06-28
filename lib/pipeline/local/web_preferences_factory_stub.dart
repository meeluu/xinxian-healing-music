import 'preferences_port.dart';

/// 非 Web 平台的 stub：调用时抛 [UnsupportedError]。
///
/// 此文件仅在非 Web 平台（VM / iOS / Android）被导入，
/// 保证 `dart:html` 不会被非 Web 平台编译。
PreferencesPort createWebLocalStoragePrefs() {
  throw UnsupportedError(
    'createWebLocalStoragePrefs() 仅在 Web 平台可用；'
    '非 Web 平台应使用 SharedPrefsAdapter(SharedPreferences)。',
  );
}
