import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'music_generation_models.dart';

/// AI 音乐生成服务（P4.3 mock 阶段）。
///
/// 封装与 `/api/generate-music` 和 `/api/music-status` 的 HTTP 交互。
/// UI 不直接拼 HTTP 请求，统一通过本服务调用。
///
/// 语义：
/// - 创建任务 → 返回 jobId + fallbackTrack
/// - 轮询状态 → 返回 MusicStatusResponse（含 progress / status / audioUrl）
/// - 失败 / 超时 → 返回 fallback 响应，不抛异常
///
/// P4.4 将保持接口不变，后端替换为真实 Stable Audio API。
class MusicGenerationService {
  final http.Client _client;

  /// 轮询间隔（默认 3 秒）
  final Duration pollInterval;

  /// 最大轮询时长（默认 150 秒）
  final Duration maxPollDuration;

  /// 单次 HTTP 请求超时
  final Duration requestTimeout;

  MusicGenerationService({
    http.Client? client,
    this.pollInterval = const Duration(seconds: 3),
    this.maxPollDuration = const Duration(seconds: 150),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// 创建音乐生成任务。
  ///
  /// 成功返回 [GenerateMusicResponse]（含 jobId）。
  /// 失败返回 [GenerateMusicResponse]（ok=false + fallbackTrack）。
  /// 任何异常都不抛出，由调用方根据 ok 字段判断。
  Future<GenerateMusicResponse> createJob(
    MusicGenerationRequest request,
  ) async {
    try {
      final resp = await _client
          .post(
            _generateEndpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(requestTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[music-gen] createJob http_${resp.statusCode}');
        return _fallbackGenerateResponse();
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return GenerateMusicResponse.fromJson(body);
    } catch (e) {
      debugPrint('[music-gen] createJob failed: $e');
      return _fallbackGenerateResponse();
    }
  }

  /// 查询任务状态（单次）。
  Future<MusicStatusResponse> getStatus({
    required String jobId,
    required String targetState,
  }) async {
    try {
      final resp = await _client
          .get(
            _statusEndpoint(jobId, targetState),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(requestTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[music-gen] getStatus http_${resp.statusCode}');
        return _fallbackStatusResponse();
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return MusicStatusResponse.fromJson(body);
    } catch (e) {
      debugPrint('[music-gen] getStatus failed: $e');
      return _fallbackStatusResponse();
    }
  }

  /// 轮询任务状态直到终态或超时。
  ///
  /// [onProgress] 回调在每次轮询返回时触发，UI 可据此更新进度。
  /// 返回最终的 [MusicStatusResponse]（终态或超时 fallback）。
  Future<MusicStatusResponse> pollUntilComplete({
    required String jobId,
    required String targetState,
    void Function(MusicStatusResponse status)? onProgress,
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final status = await getStatus(jobId: jobId, targetState: targetState);
      onProgress?.call(status);

      if (status.isTerminal) {
        return status;
      }

      // 超时检查
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > maxPollDuration) {
        debugPrint('[music-gen] poll timeout after ${elapsed.inSeconds}s');
        return _fallbackStatusResponse();
      }

      await Future.delayed(pollInterval);
    }
  }

  /// 关闭 HTTP client（如果为内部创建的）
  void dispose() {
    _client.close();
  }

  // ─── 内部 helper ──────────────────────────────────────────────

  Uri _generateEndpoint() => Uri.base.resolve('/api/generate-music');

  Uri _statusEndpoint(String jobId, String targetState) {
    final base = Uri.base.resolve('/api/music-status');
    return base.replace(queryParameters: {
      'id': jobId,
      'targetState': targetState,
    });
  }

  /// 网络失败时的 fallback 生成响应
  GenerateMusicResponse _fallbackGenerateResponse() {
    return GenerateMusicResponse(
      ok: false,
      reason: 'network_error',
      fallbackTrack: const FallbackTrack(
        audioAssetId: '',
        audioAssetTitle: '',
        audioUrl: '',
      ),
    );
  }

  /// 网络失败时的 fallback 状态响应
  MusicStatusResponse _fallbackStatusResponse() {
    return const MusicStatusResponse(
      ok: false,
      status: 'fallback',
      reason: 'network_error',
      fallbackTrack: FallbackTrack(
        audioAssetId: '',
        audioAssetTitle: '',
        audioUrl: '',
      ),
    );
  }
}
