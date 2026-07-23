import 'dart:convert';

import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

/// 「把困惑写成一首歌」AI 生成歌曲的本地每日额度保护（P6-quota-guard-1）。
///
/// 目的：在未来 realCallsEnabled 被打开后，防止用户误点 / 多点 / 重复生成
/// 导致 MiniMax 真实调用成本失控。仅约束「生成这首歌（实验）」+「重新生成」，
/// **不影响**「快速舒缓一下」固定曲库播放链路。
///
/// 规则：
/// - 默认每天最多 [dailyLimit] 次成功生成（本批 = 1）
/// - 只有 /api/generate-music 返回成功且拿到可播放音频时才计数（由调用方保证，
///   service 仅暴露 [recordSuccessfulGeneration] 作为唯一自增入口）
/// - 失败 / 取消费用确认 / 重新播放 / 编辑歌词 / 重新生成失败 都不计数
/// - 跨天自动重置（按本地日期 yyyy-MM-dd）
///
/// 存储：单 key JSON `{"date":"yyyy-MM-dd","count":N}`，损坏回退 `{今天,0}`。
/// 底层由 [PreferencesPort] 抽象（SharedPreferences 优先，Web 端 localStorage fallback），
/// 便于在测试中注入内存版 PreferencesPort。
///
/// 时钟可注入 [now]（默认 [DateTime.now]），用于测试跨天重置而无需真实等待。
///
/// 降级：当此服务未装配（存储全不可用）时，UI 侧判空跳过额度限制（permissive 降级），
/// 因为存储全不可用时整个 app 已退化为 mock 模式，且 realCallsEnabled 默认 false，
/// 真实成本风险近零。
class LocalGenerationQuotaService {
  static const String key = 'xinxian.generation.quota';

  /// 每天最多成功生成次数。
  static const int dailyLimit = 1;

  final PreferencesPort _prefs;

  /// 可注入时钟，用于测试跨天重置。
  final DateTime Function() _now;

  /// 当前记账日期（yyyy-MM-dd）。
  String _todayDate;

  /// 当前记账日期内已成功生成次数。
  int _todayCount;

  LocalGenerationQuotaService._(
    this._prefs,
    this._now,
    this._todayDate,
    this._todayCount,
  );

  /// 从磁盘加载；损坏/缺失回退 `{今天,0}`；加载时自动跨天重置。
  ///
  /// [now] 可选时钟注入，生产环境使用默认 [DateTime.now]。
  static Future<LocalGenerationQuotaService> create(
    PreferencesPort prefs, {
    DateTime Function()? now,
  }) async {
    final clock = now ?? DateTime.now;
    final todayDate = _todayString(clock());
    String loadedDate = todayDate;
    int count = 0;

    try {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final d = decoded['date'];
          if (d is String && d.isNotEmpty) {
            loadedDate = d;
          }
          final c = decoded['count'];
          if (c is int) {
            count = c;
          } else if (c is num) {
            count = c.toInt();
          }
        }
      }
    } catch (_) {
      // 损坏 JSON / 读取异常 → 空缓存起步
      loadedDate = todayDate;
      count = 0;
    }

    // 防御性：负数或异常大值归零
    if (count < 0) count = 0;

    final svc = LocalGenerationQuotaService._(prefs, clock, loadedDate, count);
    // 加载后立即跨天重置（若存储的日期不是今天）
    await svc.resetIfNewDay();
    return svc;
  }

  /// 今日已成功生成次数。
  int getTodayUsage() => _todayCount;

  /// 今日剩余可生成次数（不低于 0）。
  int get todayRemaining {
    final r = dailyLimit - _todayCount;
    return r < 0 ? 0 : r;
  }

  /// 今日是否还能生成。
  bool canGenerateToday() => _todayCount < dailyLimit;

  /// 跨天自动重置：若当前日期 != [_todayDate]，重置 count=0、date=今天、持久化。
  ///
  /// 同日调用为 no-op（不减少计数），因此「重新播放 / 编辑歌词 / 失败」等操作
  /// 即使触发此方法也不会消耗额度。
  Future<void> resetIfNewDay() async {
    final today = _todayString(_now());
    if (today == _todayDate) return;
    _todayDate = today;
    _todayCount = 0;
    await _persist();
  }

  /// 记录一次成功生成（仅在生成成功且拿到可播放音频时调用）。
  ///
  /// 先跨天重置（保证记账日期正确），再 count++ 并持久化。
  /// 这是唯一会自增 [_todayCount] 的方法。
  Future<void> recordSuccessfulGeneration() async {
    await resetIfNewDay();
    _todayCount += 1;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final encoded = jsonEncode({'date': _todayDate, 'count': _todayCount});
      await _prefs.setString(key, encoded);
    } catch (_) {
      // 持久化失败不影响当前会话使用（内存态已更新）
    }
  }

  static String _todayString(DateTime dt) => dt.toIso8601String().substring(0, 10);
}
