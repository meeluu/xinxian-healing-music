/// 应用版本信息（单一来源）。
///
/// 每次完成一个里程碑（M4 / M5 / M6 ...）后，**只需修改本文件**中的常量，
/// 首页底部与"关于"对话框会自动展示最新版本号，方便确认线上是否部署了最新版本。
///
/// 修改步骤：
/// 1. 更新 [milestone]（例如 M5 → M6）
/// 2. 更新 [versionName]（例如 v0.5.0 → v0.6.0）
/// 3. 更新 [buildLabel]（例如 M5-dev → M6-dev / M6-preview / M6-stable）
/// 4. 更新 [buildDate] 为当日日期（YYYY-MM-DD）
/// 5. 如部署平台变更，更新 [deployTarget]
///
/// 不要把版本号散落到其他页面，所有展示都从本文件读取。
class AppVersion {
  AppVersion._();

  /// 应用名称。
  static const String appName = '心弦';

  /// 当前里程碑阶段（M1 / M2 / ... / M8.1）。
  static const String milestone = 'M8.1';

  /// 语义化版本号（与里程碑对应：M4 → v0.4.x，M5 → v0.5.x，M6 → v0.6.x，M7 → v0.7.x，M8 → v0.8.x）。
  static const String versionName = 'v0.8.1';

  /// 构建标签，用于区分开发 / 预览 / 正式版本。
  ///
  /// 约定：
  /// - `M{n}-dev`：开发中
  /// - `M{n}-preview`：预览部署
  /// - `M{n}-stable`：正式发布
  static const String buildLabel = 'M8.1-dev';

  /// 构建日期（YYYY-MM-DD），手动维护。
  static const String buildDate = '2026-07-10';

  /// 部署目标平台。
  static const String deployTarget = 'Cloudflare Pages';

  /// 首页底部一行简版版本号，例如：
  /// `心弦 v0.5.0 · M5-dev · Cloudflare Pages`
  static String get shortLine =>
      '$appName $versionName · $buildLabel · $deployTarget';

  /// "关于"对话框中展示的完整版本信息（多行）。
  static const String fullLine =
      '$appName $versionName · $milestone · $buildLabel\n'
      '构建日期：$buildDate\n'
      '部署平台：$deployTarget';
}
