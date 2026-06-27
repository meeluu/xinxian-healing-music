/// 消融实验分组。
///
/// M1 阶段恒返回 [custom]；后续真实实验会按策略分配。
enum ExperimentVariant {
  /// 个性化方案（当前 Demo 默认）
  custom,

  /// 通用方案（基线对照）
  generic,

  /// 空白对照
  control,
}
