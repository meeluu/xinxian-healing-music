import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xinxian_healing_music/pipeline/music_generation/music_generation_models.dart';
import 'package:xinxian_healing_music/pipeline/music_generation/music_generation_service.dart';

void main() {
  group('MusicGenerationModels', () {
    test('MusicGenerationRequest 序列化正确', () {
      final req = const MusicGenerationRequest(
        sessionId: 'sess_123',
        targetState: 'sleep',
        generationPrompt: 'ambient sleep music, no vocals, 5 minutes',
        durationSeconds: 300,
        clientVersion: 'v1.0.0',
      );
      final json = req.toJson();
      expect(json['sessionId'], 'sess_123');
      expect(json['targetState'], 'sleep');
      expect(json['durationSeconds'], 300);
      expect(json['clientVersion'], 'v1.0.0');
    });

    test('GenerateMusicResponse 解析成功响应', () {
      final json = {
        'ok': true,
        'jobId': 'job_abc123',
        'status': 'queued',
        'fallbackTrack': {
          'audioAssetId': 'sleep_01',
          'audioAssetTitle': '夜色舒缓',
          'audioUrl': '/assets/music/sleep_01.mp3',
        },
        'estimatedSeconds': 5,
        'provider': 'mock',
      };
      final resp = GenerateMusicResponse.fromJson(json);
      expect(resp.ok, true);
      expect(resp.jobId, 'job_abc123');
      expect(resp.fallbackTrack.audioAssetId, 'sleep_01');
      expect(resp.provider, 'mock');
    });

    test('GenerateMusicResponse 解析失败响应', () {
      final json = {
        'ok': false,
        'reason': 'rate_limited',
        'fallbackTrack': {
          'audioAssetId': 'sleep_01',
          'audioAssetTitle': '夜色舒缓',
          'audioUrl': '/assets/music/sleep_01.mp3',
        },
      };
      final resp = GenerateMusicResponse.fromJson(json);
      expect(resp.ok, false);
      expect(resp.reason, 'rate_limited');
      expect(resp.fallbackTrack.audioUrl, '/assets/music/sleep_01.mp3');
    });

    test('MusicStatusResponse 解析 succeeded', () {
      final json = {
        'ok': true,
        'jobId': 'job_abc',
        'status': 'succeeded',
        'audioUrl': '/assets/music/sleep_01.mp3',
        'fallbackTrack': {
          'audioAssetId': 'sleep_01',
          'audioAssetTitle': '夜色舒缓',
          'audioUrl': '/assets/music/sleep_01.mp3',
        },
        'progress': 100,
        'elapsedSeconds': 5,
        'provider': 'mock',
      };
      final resp = MusicStatusResponse.fromJson(json);
      expect(resp.isSucceeded, true);
      expect(resp.isTerminal, true);
      expect(resp.needsFallback, false);
      expect(resp.audioUrl, '/assets/music/sleep_01.mp3');
    });

    test('MusicStatusResponse 解析 failed', () {
      final json = {
        'ok': true,
        'jobId': 'job_abc',
        'status': 'failed',
        'audioUrl': null,
        'fallbackTrack': {
          'audioAssetId': 'sleep_01',
          'audioAssetTitle': '夜色舒缓',
          'audioUrl': '/assets/music/sleep_01.mp3',
        },
        'errorCode': 'mock_random_failure',
        'progress': 85,
        'elapsedSeconds': 4,
        'provider': 'mock',
      };
      final resp = MusicStatusResponse.fromJson(json);
      expect(resp.isSucceeded, false);
      expect(resp.isTerminal, true);
      expect(resp.needsFallback, true);
      expect(resp.errorCode, 'mock_random_failure');
    });

    test('MusicGenerationPhase fromStatus 映射正确', () {
      expect(
        MusicGenerationPhase.fromStatus('queued'),
        MusicGenerationPhase.queued,
      );
      expect(
        MusicGenerationPhase.fromStatus('generating'),
        MusicGenerationPhase.generating,
      );
      expect(
        MusicGenerationPhase.fromStatus('succeeded'),
        MusicGenerationPhase.succeeded,
      );
      expect(
        MusicGenerationPhase.fromStatus('failed'),
        MusicGenerationPhase.failed,
      );
      expect(
        MusicGenerationPhase.fromStatus('fallback'),
        MusicGenerationPhase.fallback,
      );
      expect(
        MusicGenerationPhase.fromStatus('unknown'),
        MusicGenerationPhase.fallback,
      );
    });
  });

  group('MusicGenerationService', () {
    test('createJob 成功返回 jobId', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'jobId': 'job_test123',
              'status': 'queued',
              'fallbackTrack': {
                'audioAssetId': 'sleep_01',
                'audioAssetTitle': '夜色舒缓',
                'audioUrl': '/assets/music/sleep_01.mp3',
              },
              'estimatedSeconds': 5,
              'provider': 'mock',
            }),
          ),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      });

      final service = MusicGenerationService(client: mockClient);
      final req = const MusicGenerationRequest(
        sessionId: 'sess_123',
        targetState: 'sleep',
        generationPrompt: 'ambient sleep music',
        durationSeconds: 300,
      );
      final resp = await service.createJob(req);

      expect(resp.ok, true);
      expect(resp.jobId, 'job_test123');
      expect(resp.fallbackTrack.audioAssetId, 'sleep_01');
      service.dispose();
    });

    test('createJob HTTP 错误返回 fallback', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = MusicGenerationService(client: mockClient);
      final req = const MusicGenerationRequest(
        sessionId: 'sess_123',
        targetState: 'sleep',
        generationPrompt: 'ambient sleep music',
        durationSeconds: 300,
      );
      final resp = await service.createJob(req);

      expect(resp.ok, false);
      service.dispose();
    });

    test('createJob 网络异常返回 fallback', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network error');
      });

      final service = MusicGenerationService(client: mockClient);
      final req = const MusicGenerationRequest(
        sessionId: 'sess_123',
        targetState: 'sleep',
        generationPrompt: 'ambient sleep music',
        durationSeconds: 300,
      );
      final resp = await service.createJob(req);

      expect(resp.ok, false);
      expect(resp.reason, 'network_error');
      service.dispose();
    });

    test('getStatus 返回 generating 状态', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'jobId': 'job_test',
              'status': 'generating',
              'audioUrl': null,
              'fallbackTrack': {
                'audioAssetId': 'sleep_01',
                'audioAssetTitle': '夜色舒缓',
                'audioUrl': '/assets/music/sleep_01.mp3',
              },
              'progress': 45,
              'elapsedSeconds': 2,
              'provider': 'mock',
            }),
          ),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      });

      final service = MusicGenerationService(client: mockClient);
      final resp = await service.getStatus(
        jobId: 'job_test',
        targetState: 'sleep',
      );

      expect(resp.ok, true);
      expect(resp.status, 'generating');
      expect(resp.isTerminal, false);
      expect(resp.progress, 45);
      service.dispose();
    });

    test('pollUntilComplete 在终态时停止轮询', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // 第一次返回 generating，第二次返回 succeeded
        if (callCount == 1) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'jobId': 'job_test',
                'status': 'generating',
                'audioUrl': null,
                'fallbackTrack': {
                  'audioAssetId': 'sleep_01',
                  'audioAssetTitle': '夜色舒缓',
                  'audioUrl': '/assets/music/sleep_01.mp3',
                },
                'progress': 50,
                'elapsedSeconds': 2,
                'provider': 'mock',
              }),
            ),
            200,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'jobId': 'job_test',
              'status': 'succeeded',
              'audioUrl': '/assets/music/sleep_01.mp3',
              'fallbackTrack': {
                'audioAssetId': 'sleep_01',
                'audioAssetTitle': '夜色舒缓',
                'audioUrl': '/assets/music/sleep_01.mp3',
              },
              'progress': 100,
              'elapsedSeconds': 5,
              'provider': 'mock',
            }),
          ),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      });

      final service = MusicGenerationService(
        client: mockClient,
        pollInterval: const Duration(milliseconds: 10),
      );

      var progressCount = 0;
      final result = await service.pollUntilComplete(
        jobId: 'job_test',
        targetState: 'sleep',
        onProgress: (status) {
          progressCount++;
        },
      );

      expect(result.isSucceeded, true);
      expect(result.isTerminal, true);
      expect(progressCount, 2); // 2 次回调
      service.dispose();
    });

    test('pollUntilComplete 网络异常返回 fallback', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network error');
      });

      final service = MusicGenerationService(
        client: mockClient,
        pollInterval: const Duration(milliseconds: 10),
        maxPollDuration: const Duration(milliseconds: 100),
      );

      final result = await service.pollUntilComplete(
        jobId: 'job_test',
        targetState: 'sleep',
      );

      expect(result.ok, false);
      expect(result.needsFallback, true);
      service.dispose();
    });
  });
}
