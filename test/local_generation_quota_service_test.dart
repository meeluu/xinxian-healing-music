import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/pipeline/local/local_generation_quota_service.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';

/// LocalGenerationQuotaService 单元测试（P6-quota-guard-1）。
///
/// 覆盖用户规格「6. 可测试性」6 项规则 + 持久化 / 损坏容错 / key 隔离：
/// 1. 初始可生成
/// 2. 成功后次数 +1
/// 3. 达到上限后不可生成
/// 4. 失败不计数
/// 5. 跨天重置
/// 6. 重新播放不计数
/// 7. 持久化 + 重启保留
/// 8. 损坏 JSON 容错
/// 9. key 隔离
///
/// service 层不提供 failure / replay 入口：计数由调用方仅在「生成成功且拿到可播放音频」
/// 时调用 [LocalGenerationQuotaService.recordSuccessfulGeneration] 保证。因此
/// 「失败不计数」「重新播放不计数」在 service 层体现为「不调用 record 则计数不变」
/// + 「resetIfNewDay 同日 no-op 不减少计数」。
void main() {
  // 固定时钟，便于测试跨天重置；跨天用例中会重新赋值。
  DateTime fixedNow = DateTime(2026, 7, 23, 10, 0);

  group('LocalGenerationQuotaService - 基本额度规则', () {
    test('1. 初始状态：今日可生成，剩余 1，已用 0', () async {
      final svc = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
        now: () => fixedNow,
      );
      expect(svc.canGenerateToday(), isTrue);
      expect(svc.todayRemaining, 1);
      expect(svc.getTodayUsage(), 0);
    });

    test('2. 成功生成一次后次数 +1，剩余 0', () async {
      final svc = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
        now: () => fixedNow,
      );
      await svc.recordSuccessfulGeneration();
      expect(svc.getTodayUsage(), 1);
      expect(svc.todayRemaining, 0);
    });

    test('3. 达到上限后不可生成', () async {
      final svc = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
        now: () => fixedNow,
      );
      await svc.recordSuccessfulGeneration();
      expect(svc.canGenerateToday(), isFalse);
      expect(svc.todayRemaining, 0);
    });

    test('4. 失败不计数：不调用 record 则计数不变', () async {
      // service 不提供 failure 入口；调用方仅在成功时调 record。
      // 模拟「生成失败」流程：不调用 record，直接读状态。
      final svc = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
        now: () => fixedNow,
      );
      expect(svc.getTodayUsage(), 0);
      expect(svc.canGenerateToday(), isTrue);
      // 即使经历了失败流程，只要不调 record，额度不被消耗
      expect(svc.todayRemaining, 1);
    });

    test('5. 跨天自动重置', () async {
      var clock = DateTime(2026, 7, 23, 10, 0);
      final fake = _FakePreferencesPort();
      final svc = await LocalGenerationQuotaService.create(fake, now: () => clock);
      await svc.recordSuccessfulGeneration();
      expect(svc.getTodayUsage(), 1);
      expect(svc.canGenerateToday(), isFalse);

      // 推进到第二天：resetIfNewDay 应清零
      clock = DateTime(2026, 7, 24, 9, 0);
      await svc.resetIfNewDay();
      expect(svc.getTodayUsage(), 0);
      expect(svc.todayRemaining, 1);
      expect(svc.canGenerateToday(), isTrue);

      // 第二天可再次成功生成
      await svc.recordSuccessfulGeneration();
      expect(svc.getTodayUsage(), 1);
    });

    test('6. 重新播放不计数：同日 resetIfNewDay 不减少计数', () async {
      // 「重新播放」语义上不触发 record；同时不应误触发跨天重置清零当日已用次数。
      final svc = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
        now: () => fixedNow,
      );
      await svc.recordSuccessfulGeneration();
      expect(svc.getTodayUsage(), 1);
      // 重新播放流程中即便调到 resetIfNewDay（同日），不应清零
      await svc.resetIfNewDay();
      expect(svc.getTodayUsage(), 1, reason: '同日 resetIfNewDay 不应减少计数');
      expect(svc.canGenerateToday(), isFalse);
    });
  });

  group('LocalGenerationQuotaService - 持久化与容错', () {
    test('7. 持久化 + 重启保留当日计数', () async {
      final fake = _FakePreferencesPort();
      final svc1 = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      await svc1.recordSuccessfulGeneration();
      // 模拟重启：用同一 storage 再次 create
      final svc2 = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      expect(svc2.getTodayUsage(), 1);
      expect(svc2.canGenerateToday(), isFalse);
      expect(svc2.todayRemaining, 0);
    });

    test('8. 损坏 JSON 回退到 {今天, 0}', () async {
      final fake = _FakePreferencesPort();
      await fake.setString(LocalGenerationQuotaService.key, '这不是合法JSON{{{');
      final svc = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      expect(svc.getTodayUsage(), 0);
      expect(svc.canGenerateToday(), isTrue);
    });

    test('8b. count 字段为非数字时回退 0', () async {
      final fake = _FakePreferencesPort();
      await fake.setString(
        LocalGenerationQuotaService.key,
        '{"date":"2026-07-23","count":"不是数字"}',
      );
      final svc = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      expect(svc.getTodayUsage(), 0);
      expect(svc.canGenerateToday(), isTrue);
    });

    test('8c. 存储日期为昨天 → 加载时自动跨天重置', () async {
      final fake = _FakePreferencesPort();
      await fake.setString(
        LocalGenerationQuotaService.key,
        '{"date":"2026-07-22","count":1}',
      );
      final svc = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      // 今天 = 2026-07-23，加载时 resetIfNewDay 应清零昨天的计数
      expect(svc.getTodayUsage(), 0);
      expect(svc.canGenerateToday(), isTrue);
    });

    test('8d. count 为负数时归零（防御性）', () async {
      final fake = _FakePreferencesPort();
      await fake.setString(
        LocalGenerationQuotaService.key,
        '{"date":"2026-07-23","count":-5}',
      );
      final svc = await LocalGenerationQuotaService.create(fake, now: () => fixedNow);
      expect(svc.getTodayUsage(), 0);
      expect(svc.canGenerateToday(), isTrue);
    });
  });

  group('LocalGenerationQuotaService - key 隔离', () {
    test('9. key 与其他 consent / 同意服务不同，避免冲突', () {
      expect(LocalGenerationQuotaService.key, 'xinxian.generation.quota');
      expect(LocalGenerationQuotaService.key, isNot('xinxian.cloud.feedback.consent'));
      expect(LocalGenerationQuotaService.key, isNot('xinxian.cloud.feedback.text.consent'));
      expect(LocalGenerationQuotaService.key, isNot('xinxian.llm.consent'));
      expect(LocalGenerationQuotaService.dailyLimit, 1);
    });
  });
}

/// 内存 Map 实现的 [PreferencesPort]，用于模拟存储（不依赖 Flutter binding）。
class _FakePreferencesPort implements PreferencesPort {
  final Map<String, String> _store = {};

  @override
  String? getString(String key) => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }
}
