import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/pipeline/ports/experiment_assigner.dart';

/// 基于 sessionId hash 的稳定实验分组分配器（M8.1 新增）。
///
/// 设计目标：
/// - **保守 MVP**：默认 `enabled=false` 时始终返回 [ExperimentVariant.custom]，
///   完全向后兼容。线上不传 `--dart-define=ENABLE_EXPERIMENT=true` 时，
///   用户体验与 M8 完全一致，不改变推荐结果。
/// - **稳定分组**：同一 sessionId 多次调用结果一致（FNV-1a 纯函数 hash，
///   跨平台跨版本确定性一致）。
/// - **可配比**：默认 1:1:1，可通过构造参数调整。
///
/// 启用方式（编译期常量，零依赖）：
/// ```
/// flutter build web --release --dart-define=ENABLE_EXPERIMENT=true
/// ```
///
/// 注意（M8.1 保守 MVP 边界）：
/// - 本分配器只决定 `experimentVariant` 字段的写入值
/// - **不**改变 [StockAudioGenerator] 的音频匹配逻辑
/// - **不**改变 [HealingPipeline] 的推荐链路
/// - generic / control 组当前仍走 custom 的完整推荐流程，
///   仅在 D1 中记录分组标签，便于后续 M8.2 启用真正的音频旁路时
///   能与历史分组数据对齐
class HashExperimentAssigner implements ExperimentAssigner {
  /// 是否启用消融分组。false 时恒返回 [ExperimentVariant.custom]。
  final bool enabled;

  /// 三组配比：(custom, generic, control)。默认 1:1:1。
  final ({int custom, int generic, int control}) ratio;

  const HashExperimentAssigner({
    this.enabled = false,
    this.ratio = const (custom: 1, generic: 1, control: 1),
  });

  @override
  ExperimentVariant assign(MoodInput input) {
    if (!enabled) return ExperimentVariant.custom;

    final total = ratio.custom + ratio.generic + ratio.control;
    if (total <= 0) return ExperimentVariant.custom;

    final bucket = _fnv1a32(input.sessionId) % total;
    if (bucket < ratio.custom) return ExperimentVariant.custom;
    if (bucket < ratio.custom + ratio.generic) {
      return ExperimentVariant.generic;
    }
    return ExperimentVariant.control;
  }

  /// FNV-1a 32-bit hash（纯算法实现，无第三方依赖）。
  ///
  /// 选择 FNV-1a 而非 `String.hashCode` 的原因：
  /// - `String.hashCode` 在不同平台 / 不同 Dart 版本下实现可能不同，
  ///   跨进程跨版本不可保证一致性
  /// - FNV-1a 是公开标准算法，对相同输入在任何环境都产生相同 32 位结果
  /// - 分布均匀性已由 `test/hash_experiment_assigner_test.dart` 验证
  static int _fnv1a32(String s) {
    var hash = 0x811C9DC5; // FNV offset basis (32-bit)
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime (32-bit)
    }
    // 保证非负（Dart 的 % 对负数会返回负余数）
    return hash >= 0 ? hash : -hash;
  }
}
