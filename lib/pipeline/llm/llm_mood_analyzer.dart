import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

/// LLM 情绪解析器：调用同域 Netlify Function `/api/analyze-mood`。
///
/// - 不持有任何 API Key / Base URL / 模型名（全部由后端 Function 管理）。
/// - 任何失败（网络、超时、非 200、ok:false、字段缺失）都抛异常，
///   由上层 [MoodAnalyzerGateway] catch 并 fallback 到 MockMoodAnalyzer。
/// - 不向用户暴露错误细节，只负责"成功返回 MoodProfile 或抛异常"。
class LlmMoodAnalyzer implements MoodAnalyzerPort {
  const LlmMoodAnalyzer();

  @override
  String get currentSource => 'llm';

  /// 解析接口的完整 URL。
  /// Web 环境下 `Uri.base` 是当前页面地址，resolve 出同域 `/api/analyze-mood`。
  /// 本地 netlify dev（localhost:8888）同样适用。
  Uri _endpoint() => Uri.base.resolve('/api/analyze-mood');

  @override
  Future<MoodProfile> analyze(MoodInput input) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'text': input.text}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // 网络错误 / 超时 / CORS 等 —— 不中断主流程，抛异常由 Gateway catch
      throw Exception('llm_network_error');
    }

    if (resp.statusCode != 200) {
      throw Exception('llm_http_${resp.statusCode}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('llm_invalid_json');
    }

    // 后端返回 ok:false（fallback）时，前端也视为失败，交给 Gateway 走 mock
    if (body['ok'] != true) {
      throw Exception('llm_backend_fallback');
    }

    final moodRaw = body['mood'];
    if (moodRaw is! Map<String, dynamic>) {
      throw Exception('llm_no_mood');
    }

    return _toMoodProfile(moodRaw, input.text);
  }

  /// 将后端返回的 mood JSON 转为 MoodProfile。
  /// 任何字段缺失/类型错误都抛异常（由 Gateway catch）。
  ///
  /// M6.1：设置 [MoodProfile.sourceText] = 用户原文，让 mapper 的
  /// [TargetStateResolver] 能用原文修正 LLM 返回的 targetState。
  MoodProfile _toMoodProfile(Map<String, dynamic> m, String sourceText) {
    final tagsRaw = m['tags'];
    if (tagsRaw is! List) throw Exception('llm_bad_tags');
    final tags = tagsRaw.map((e) => e.toString()).toList();

    final valence = (m['valence'] as num?)?.toDouble();
    final arousal = (m['arousal'] as num?)?.toDouble();
    final intensity = (m['intensity'] as num?)?.toDouble();
    final summary = m['summary'] as String?;
    final targetName = m['targetState'] as String?;
    final dominantNeed = m['dominantNeed'] as String?;

    if (valence == null || arousal == null || summary == null) {
      throw Exception('llm_missing_fields');
    }

    return MoodProfile(
      tags: tags,
      valence: valence,
      arousal: arousal,
      intensity: intensity ?? 0.5,
      summary: summary,
      targetState: TargetState.fromName(targetName),
      dominantNeed: dominantNeed,
      sourceText: sourceText,
    );
  }
}
