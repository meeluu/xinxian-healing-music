import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';

/// 困惑解惑 + 歌词生成 Service（P4 新方向第一批）。
///
/// 职责：调用同域 Cloudflare Pages Function `/api/comfort-lyrics`，
/// 返回 [ComfortLyricsResult]。
///
/// - 不持有任何 API Key / Base URL / 模型名（全部由后端 Function 管理）。
/// - 任何失败（网络、超时、非 200、JSON 解析失败）都返回本地 fallback，
///   不抛异常，不让前端卡死（与 [LlmMoodAnalyzer] 不同：后者失败由
///   [MoodAnalyzerGateway] catch 并 fallback 到 Mock）。
/// - 后端 `ok: false`（fallback）时也正常返回 [ComfortLyricsResult]，
///   [ComfortLyricsResult.source] = 'fallback'，前端可据此显示"本地模板"提示。
///
/// 本批不调用 MiniMax / Mureka，不生成真实音频。
class ComfortLyricsService {
  const ComfortLyricsService();

  /// 解析接口的完整 URL。
  /// Web 环境下 `Uri.base` 是当前页面地址，resolve 出同域 `/api/comfort-lyrics`。
  Uri _endpoint() => Uri.base.resolve('/api/comfort-lyrics');

  /// 调用后端生成解惑 + 歌词草稿。
  ///
  /// - [storyText]：用户输入的困惑/事件/情绪描述（≤1000 字）
  /// - [sessionId]：会话 ID（可选，后端会兜底空串）
  /// - [targetStyle]：期望曲风（gentle_pop / ambient_ballad / acoustic_warm / soft_piano）
  /// - [language]：语言（默认 zh-CN）
  ///
  /// 任何异常都返回本地 fallback，绝不抛异常。
  Future<ComfortLyricsResult> generate({
    required String storyText,
    String sessionId = '',
    String targetStyle = 'gentle_pop',
    String language = 'zh-CN',
  }) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'storyText': storyText,
              'sessionId': sessionId,
              'targetStyle': targetStyle,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // 网络错误 / 超时 / CORS —— 不让用户卡死，返回前端本地 fallback
      return _localFallback(storyText, targetStyle);
    }

    if (resp.statusCode != 200) {
      return _localFallback(storyText, targetStyle);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return _localFallback(storyText, targetStyle);
    }

    // 后端返回 ok:false（fallback）时也正常返回，前端可显示来源标记
    final comfort = body['comfortInterpretation'] as String?;
    final lyric = body['lyricDraft'] as String?;
    if (comfort == null || comfort.isEmpty || lyric == null || lyric.isEmpty) {
      return _localFallback(storyText, targetStyle);
    }

    return ComfortLyricsResult.fromJson(body);
  }

  /// 前端本地 fallback（网络完全不可达时使用）。
  ///
  /// 与后端 `localFallback` 保持文案一致，确保用户在任何情况下都能看到
  /// 一段温和的解惑 + 歌词草稿。
  ComfortLyricsResult _localFallback(String storyText, String targetStyle) {
    final comfortInterpretation = [
      '听起来你最近承受了一些不容易的事，谢谢你愿意把它说出来。',
      '也许现在的你不需要立刻找到答案，也不需要把所有事都理清楚。先允许自己停一下，就停在这里。',
      '可以试着给自己倒一杯水，或者把窗户打开透透气。很小的一步，就够了。',
    ].join('\n\n');

    final lyricDraft = [
      '【主歌】',
      '你站在夜色里没说话',
      '风把心事吹得有些远',
      '想哭也没关系，我在听',
      '',
      '【副歌】',
      '也许明天先把杯子洗干净',
      '也许今晚试着把手机放远一点',
      '不用急着好起来',
      '这首歌想陪你看见自己',
      '',
      '【尾声】',
      '天快亮了，你不用一个人。',
    ].join('\n');

    final songPrompt = _fallbackSongPrompt(targetStyle);

    return ComfortLyricsResult(
      comfortInterpretation: comfortInterpretation,
      lyricDraft: lyricDraft,
      songPrompt: songPrompt,
      safetyNotes: 'fallback_mode（前端本地模板）',
      source: 'fallback',
    );
  }

  /// 根据 targetStyle 选择 fallback songPrompt。
  ///
  /// 与后端 `localFallback` 的 songPromptMap 保持一致。
  /// 抽成独立方法避免在 const 上下文中调用 Map 索引（const_eval_method_invocation）。
  static String _fallbackSongPrompt(String targetStyle) {
    switch (targetStyle) {
      case 'ambient_ballad':
        return 'ambient ballad, soft pads, slow tempo, calming, no vocals';
      case 'acoustic_warm':
        return 'warm acoustic, fingerstyle guitar, slow tempo, comforting, no vocals';
      case 'soft_piano':
        return 'soft piano, gentle melody, slow tempo, peaceful, no vocals';
      case 'gentle_pop':
      default:
        return 'gentle pop, acoustic guitar, slow tempo, warm mood, no vocals';
    }
  }
}
