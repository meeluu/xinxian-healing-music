import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/pipeline/experiment/hash_experiment_assigner.dart';

/// M8.1：HashExperimentAssigner 测试。
///
/// 覆盖：
/// 1. enabled=false 时恒返回 custom（向后兼容）
/// 2. 同一 sessionId 多次 assign 结果稳定
/// 3. enabled=true 时 1000 个模拟 sessionId 分布覆盖三组
///    （不要求严格 1/3，但任一组占比不低于 20%，任一组不为 0）
/// 4. 自定义配比生效
/// 5. 空 sessionId 兜底
void main() {
  MoodInput buildInput(String sessionId) {
    return MoodInput(
      sessionId: sessionId,
      text: '测试心境',
      timestamp: DateTime(2026, 7, 1),
    );
  }

  group('HashExperimentAssigner - enabled=false（默认保守模式）', () {
    final assigner = const HashExperimentAssigner(enabled: false);

    test('恒返回 ExperimentVariant.custom', () {
      for (var i = 0; i < 100; i++) {
        final input = buildInput('sess-test-$i');
        expect(assigner.assign(input), ExperimentVariant.custom,
            reason: 'enabled=false 时必须始终返回 custom');
      }
    });

    test('空 sessionId 也返回 custom', () {
      final input = buildInput('');
      expect(assigner.assign(input), ExperimentVariant.custom);
    });
  });

  group('HashExperimentAssigner - 稳定性', () {
    final assigner = const HashExperimentAssigner(enabled: true);

    test('同一 sessionId 多次 assign 结果一致', () {
      final sessionIds = [
        'sess-lq8a2k-1a2b',
        'sess-lq8a2k-3c4d',
        'sess-lq8a2k-5e6f',
        'sess-mb9x7z-7g8h',
        'sess-mb9x7z-9i0j',
        'sess-unique-aaa1',
        'sess-unique-bbb2',
        'sess-unique-ccc3',
      ];
      for (final sid in sessionIds) {
        final input = buildInput(sid);
        final first = assigner.assign(input);
        // 重复 10 次必须完全一致
        for (var i = 0; i < 10; i++) {
          expect(assigner.assign(input), first,
              reason: 'sessionId=$sid 第 $i 次分配与首次不一致，hash 不稳定');
        }
      }
    });

    test('相同 sessionId 在不同 assigner 实例下结果一致', () {
      // 不同实例（相同配置）对同一 sessionId 应产生相同分组
      const a1 = HashExperimentAssigner(enabled: true);
      const a2 = HashExperimentAssigner(enabled: true);
      for (var i = 0; i < 50; i++) {
        final input = buildInput('sess-cross-instance-$i');
        expect(a1.assign(input), a2.assign(input),
            reason: '跨实例分配不一致，FNV-1a 应为纯函数');
      }
    });
  });

  group('HashExperimentAssigner - 分布均匀性', () {
    test('1000 个模拟 sessionId 三组均不为 0 且占比 20%-50%', () {
      const assigner = HashExperimentAssigner(enabled: true);

      final counts = <ExperimentVariant, int>{
        ExperimentVariant.custom: 0,
        ExperimentVariant.generic: 0,
        ExperimentVariant.control: 0,
      };

      // 模拟 1000 个真实 sessionId（格式 sess-{timestamp_base36}-{random_4}）
      for (var i = 0; i < 1000; i++) {
        // 模拟时间戳部分（base36）
        final ts = (1770000000000 + i * 60000).toRadixString(36);
        // 模拟随机后缀
        final r = (i * 2654435761 % 0xffffff).toRadixString(36).padLeft(4, '0');
        final sid = 'sess-$ts-$r';
        final v = assigner.assign(buildInput(sid));
        counts[v] = counts[v]! + 1;
      }

      // 断言：三组都不为 0
      for (final entry in counts.entries) {
        expect(entry.value, greaterThan(0),
            reason: '${entry.key} 组样本数为 0，hash 分布严重不均');
      }

      // 断言：每组占比 20%-50%（理论 33.3%，留 ±17% 容差）
      const total = 1000;
      for (final entry in counts.entries) {
        final ratio = entry.value / total;
        expect(ratio, greaterThanOrEqualTo(0.20),
            reason: '${entry.key} 组占比 ${ratio.toStringAsFixed(3)} < 0.20');
        expect(ratio, lessThanOrEqualTo(0.50),
            reason: '${entry.key} 组占比 ${ratio.toStringAsFixed(3)} > 0.50');
      }

      // 打印分布（debug 用，测试报告中可见）
      // ignore: avoid_print
      print('1000 样本分布: '
          'custom=${counts[ExperimentVariant.custom]}, '
          'generic=${counts[ExperimentVariant.generic]}, '
          'control=${counts[ExperimentVariant.control]}');
    });

    test('连续 sessionId 序列分布覆盖三组', () {
      // 用连续整数作为 sessionId，验证简单输入下也能分散到三组
      const assigner = HashExperimentAssigner(enabled: true);
      final variants = <ExperimentVariant>{};
      for (var i = 0; i < 100; i++) {
        variants.add(assigner.assign(buildInput('sess-$i')));
      }
      expect(variants.length, 3,
          reason: '100 个连续 sessionId 应覆盖全部三组，实际: $variants');
    });
  });

  group('HashExperimentAssigner - 自定义配比', () {
    test('配比 (3, 1, 1) 时 custom 组占比约 60%', () {
      const assigner = HashExperimentAssigner(
        enabled: true,
        ratio: (custom: 3, generic: 1, control: 1),
      );

      final counts = <ExperimentVariant, int>{
        ExperimentVariant.custom: 0,
        ExperimentVariant.generic: 0,
        ExperimentVariant.control: 0,
      };

      for (var i = 0; i < 1000; i++) {
        final v = assigner.assign(buildInput('sess-ratio-$i'));
        counts[v] = counts[v]! + 1;
      }

      // custom 应占 ~60%，generic ~20%，control ~20%
      final customRatio = counts[ExperimentVariant.custom]! / 1000;
      expect(customRatio, greaterThan(0.50),
          reason: '配比 3:1:1 下 custom 应占主导，实际占比 $customRatio');
      expect(counts[ExperimentVariant.generic]!, greaterThan(0));
      expect(counts[ExperimentVariant.control]!, greaterThan(0));
    });

    test('配比 (1, 0, 0) 时恒返回 custom（generic/control 配比为 0）', () {
      const assigner = HashExperimentAssigner(
        enabled: true,
        ratio: (custom: 1, generic: 0, control: 0),
      );
      for (var i = 0; i < 100; i++) {
        expect(assigner.assign(buildInput('sess-only-custom-$i')),
            ExperimentVariant.custom);
      }
    });
  });

  group('HashExperimentAssigner - 边界', () {
    test('空 sessionId 在 enabled=true 时不抛异常', () {
      const assigner = HashExperimentAssigner(enabled: true);
      final v = assigner.assign(buildInput(''));
      expect(
        [ExperimentVariant.custom, ExperimentVariant.generic, ExperimentVariant.control],
        contains(v),
      );
    });

    test('超长 sessionId 不抛异常', () {
      const assigner = HashExperimentAssigner(enabled: true);
      final longSid = 'sess-${'a' * 10000}';
      final v = assigner.assign(buildInput(longSid));
      expect(
        [ExperimentVariant.custom, ExperimentVariant.generic, ExperimentVariant.control],
        contains(v),
      );
    });
  });
}
