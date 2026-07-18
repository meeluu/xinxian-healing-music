/// 困惑解惑 + 歌词生成结果（P4 新方向第一批）。
///
/// 对应后端 `functions/api/comfort-lyrics.js` 的响应：
/// - [comfortInterpretation]：温和解惑文本（150-300 字，2-4 段）
/// - [lyricDraft]：中文歌词草稿（80-150 字，含「主歌」「副歌」「尾声」标记）
/// - [songPrompt]：后续 AI 音乐生成的风格提示（英文，20-40 字）
/// - [safetyNotes]：安全检查备注
/// - [source]：来源 'llm' / 'fallback'
///
/// 不依赖真实 AI 音乐生成 API；本批只完成「解惑 + 歌词草稿」。
class ComfortLyricsResult {
  /// 温和解惑文本。
  final String comfortInterpretation;

  /// 中文歌词草稿。
  final String lyricDraft;

  /// 后续 AI 音乐生成的风格提示。
  final String songPrompt;

  /// 安全检查备注。
  final String safetyNotes;

  /// 来源：'llm' / 'fallback' / 'mock'。
  final String source;

  /// 是否来自 fallback（本地模板，非 LLM）。
  bool get isFallback => source != 'llm';

  const ComfortLyricsResult({
    required this.comfortInterpretation,
    required this.lyricDraft,
    required this.songPrompt,
    required this.safetyNotes,
    required this.source,
  });

  /// 从后端 JSON 响应构造。
  ///
  /// 兼容两种情况：
  /// - `ok: true, source: 'llm'` —— LLM 成功
  /// - `ok: false, source: 'fallback'` —— LLM 失败，后端已返回本地 fallback 文案
  ///
  /// 两种情况都会返回 [ComfortLyricsResult]，前端不抛异常（不让用户卡死）。
  factory ComfortLyricsResult.fromJson(Map<String, dynamic> json) {
    return ComfortLyricsResult(
      comfortInterpretation:
          (json['comfortInterpretation'] as String?) ?? '',
      lyricDraft: (json['lyricDraft'] as String?) ?? '',
      songPrompt: (json['songPrompt'] as String?) ?? '',
      safetyNotes: (json['safetyNotes'] as String?) ?? '',
      source: (json['source'] as String?) ?? 'fallback',
    );
  }
}
