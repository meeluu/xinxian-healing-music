import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

/// 音频 asset 路径解析结果（供测试与调试用）。
///
/// [AudioAssetUriResolver.resolveAudioSource] 返回的是 [AudioSource] 实例，
/// 不便于直接断言；[AudioAssetUriResolver.describe] 返回本类，
/// 让测试可以验证解析逻辑（asset key / Web URL / 是否走 AssetBundle）。
class AudioAssetPath {
  /// 原始 asset key，例如 'music/sleep_01.mp3'
  final String assetKey;

  /// Web 下使用的相对 URL，例如 'assets/music/sleep_01.mp3'。
  ///
  /// 非 Web 平台为 null（继续走 [AudioSource.asset]）。
  final String? webUrl;

  /// 是否使用 [AudioSource.asset]（true）或 [AudioSource.uri]（false）。
  final bool useAssetSource;

  const AudioAssetPath({
    required this.assetKey,
    required this.useAssetSource,
    this.webUrl,
  });
}

/// 音频 asset 路径解析器（M6 修复 Flutter Web 加载问题）。
///
/// 根因：just_audio 的 [AudioSource.asset] 在 Flutter Web 上有已知问题。
/// just_audio Web 后端基于 HTML5 `<audio>` 元素，需要 URL 而非 asset key。
/// `AudioSource.asset` 内部走 `rootBundle`，在 Web + just_audio 组合下经常报
/// "Unable to load asset: ... The asset does not exist or has empty data."。
///
/// 解决方案：
/// - Web：用 [AudioSource.uri] 指向相对 URL `assets/<assetKey>`，
///   浏览器基于 `<base href>` 解析为正确的绝对 URL。
/// - 非 Web（移动端 / 桌面端）：继续用 [AudioSource.asset]，走 AssetBundle。
///
/// 设计原则：
/// 1. 不修改模型层的 assetPath（仍是 Flutter asset key，移动端兼容）
/// 2. 不破坏历史记录中保存的旧 assetPath（空字符串时 fallback 到默认音频）
/// 3. PlayerScreen 统一调用 [resolveAudioSource]，不直接拼路径
class AudioAssetUriResolver {
  AudioAssetUriResolver._();

  /// 默认兜底音频 asset key（与 AudioAssetCatalog.fallback 一致）。
  ///
  /// assetPath 为空时使用，保证旧历史记录（可能缺 assetPath）也能播放。
  static const String defaultAssetKey = 'music/sleep_01.mp3';

  /// asset 文件在 Flutter Web 构建产物中的目录前缀。
  ///
  /// `flutter build web` 会把所有 asset 复制到 `build/web/assets/<key>`，
  /// 对应运行时的相对 URL 为 `assets/<key>`。
  static const String _webAssetsPrefix = 'assets/';

  /// 根据 asset key 返回平台对应的 [AudioSource]。
  ///
  /// PlayerScreen 应统一调用本方法，不要直接构造 [AudioSource.asset] / [AudioSource.uri]。
  ///
  /// - [assetKey] 为空时 fallback 到 [defaultAssetKey]
  /// - Web：[AudioSource.uri] 指向 `assets/<assetKey>`
  /// - 非 Web：[AudioSource.asset] 指向 `<assetKey>`
  static AudioSource resolveAudioSource(String assetKey) {
    final resolved = describe(assetKey);
    if (resolved.useAssetSource) {
      return AudioSource.asset(resolved.assetKey);
    }
    // ignore: null_check_on_nullable_type_parameter
    return AudioSource.uri(Uri.parse(resolved.webUrl!));
  }

  /// 解析 asset key 为平台对应的路径描述（供测试用）。
  ///
  /// 不构造 [AudioSource]，只返回解析结果，便于测试断言。
  static AudioAssetPath describe(String assetKey) {
    final key = assetKey.isEmpty ? defaultAssetKey : assetKey;
    if (kIsWeb) {
      return AudioAssetPath(
        assetKey: key,
        webUrl: '$_webAssetsPrefix$key',
        useAssetSource: false,
      );
    }
    return AudioAssetPath(
      assetKey: key,
      useAssetSource: true,
    );
  }
}
