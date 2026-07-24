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

  /// 当前里程碑阶段（M1 / M2 / ... / M8.1 / P1-Web-v1.0 / P2-Web-v1.0 / P3-Web-v1.0 / P4-AI-Music-v1.0）。
  static const String milestone = 'P4-AI-Music-v1.0';

  /// 语义化版本号（与里程碑对应：M4 → v0.4.x，M5 → v0.5.x，M6 → v0.6.x，M7 → v0.7.x，M8 → v0.8.x，P2 → v0.9.x，P3/P4 → v1.0.x）。
  static const String versionName = 'v1.0.0';

  /// 构建标签，用于区分开发 / 预览 / 正式版本。
  ///
  /// 约定：
  /// - `M{n}-dev`：开发中
  /// - `M{n}-preview`：预览部署
  /// - `M{n}-stable`：正式发布
  /// - `P{N}-ui-{n}`：P 阶段第 n 批 UI / 体验优化
  /// - `P{N}-data-{n}`：P 阶段第 n 批数据 / 脚本扩展
  /// - `P{N}-research-{n}`：P 阶段第 n 批技术调研与方案设计
  /// - `P{N}-research-{n}-fix{m}`：P 阶段第 n 批调研的第 m 次复核修订
  /// - `P{N}-design-{n}`：P 阶段第 n 批接入设计（接口/数据/Prompt/前端架构）
  /// - `P{N}-mock-{n}`：P 阶段第 n 批 mock/adapter 最小闭环实现
  /// - `P{N}-mock-{n}-fix{m}`：P 阶段第 n 批 mock 的第 m 次交互修复
  /// - `P{N}-provider-design-{n}`：P 阶段第 n 批 provider adapter 与密钥/成本控制设计
  /// - `P{N}-provider-skeleton-{n}`：P 阶段第 n 批 provider adapter 代码骨架实现
  /// - `P{N}-replicate-skeleton-{n}`：P 阶段第 n 批 Replicate MusicGen provider 骨架
  /// - `P{N}-minimax-skeleton-{n}`：P 阶段第 n 批 MiniMax Music provider 骨架
  /// - `P{N}-minimax-realtest-{n}`：P 阶段第 n 批 MiniMax Music 真实调用测试（受双重开关保护）
  /// - `P{N}-comfort-song-design-{n}`：P 阶段第 n 批「困惑解惑→歌词→AI 歌曲」新方向产品设计
  /// - `P{N}-comfort-song-design-{n}-fix{m}`：P 阶段第 n 批新方向产品设计的第 m 次修订
  /// - `P{N}-comfort-lyrics-{n}`：P 阶段第 n 批「困惑解惑 + 歌词生成」LLM 流程代码实现
  /// - `P{N}-lyrics-edit-{n}`：P 阶段第 n 批歌词确认/编辑 + 后续生成按钮占位
  /// - `P{N}-minimax-song-gray-{n}`：P 阶段第 n 批 MiniMax 歌曲生成灰度接入（三重门保护，默认不开放前端真实调用）
  /// - `P{N}-home-structure-{n}`：P 阶段第 n 批前端结构调整（首页/页面信息架构重构，只调前端不改后端）
  /// - `P{N}-minimax-real-test-{n}`：P 阶段第 n 批 MiniMax 真实生成链路受控测试（手动 curl 真实调用，仓库默认 REAL_CALLS=false）
  /// - `P{N}-generated-audio-playback-{n}`：P 阶段第 n 批 MiniMax 生成音频落地播放链路（audioHex → R2 → 前端播放闭环）
  /// - `P{N}-temp-audio-playback-{n}`：P 阶段第 n 批 MiniMax 生成音频临时播放闭环（audioHex → base64 dataUrl → 前端播放，不依赖 R2）
  /// - `P{N}-temp-audio-playback-{n}-cleanup`：P 阶段第 n 批临时播放闭环的代码审计清理版本（线上试听验证通过后的收尾）
  /// - `P{N}-song-result-experience-{n}`：P 阶段第 n 批生成歌曲结果页体验优化（纯前端，不改后端真实调用策略）
  /// - `P{N}-quota-guard-{n}`：P 阶段第 n 批本地额度保护与成本安全（浏览器每日生成次数限制）
  /// - `P{N}-playback-experience-{n}`：P 阶段第 n 批播放体验优化（AI 歌曲独立播放页 + 本地播放模式增强）
  /// - `P{N}-music-metadata-foundation-{n}`：P 阶段第 n 批本地音乐元数据基础改造（per-asset 时长 / 声音特征结构打通）
  /// - `P{N}-dynamic-followup-depth-{n}`：P 阶段第 n 批动态追问深度优化（固定三轮→动态 2-4 轮）
  /// - `P{N}-stable`：P 阶段收尾验收通过，正式发布
  static const String buildLabel = 'P4-dynamic-followup-depth-1';

  /// 构建日期（YYYY-MM-DD），手动维护。
  static const String buildDate = '2026-07-24';

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
