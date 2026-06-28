import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';

/// 云端反馈上传 Port（M7 新增）。
///
/// 与本地 [FeedbackRepository] 并存（非替换）：
/// - 本地仓储负责持久化历史记录，UI 层直接读写
/// - 云端上传是 fire-and-forget 单向操作，失败不影响用户体验
///
/// 实现类：
/// - [HttpCloudFeedbackUploader]：生产实现，调用同域 /api/submit-feedback
/// - [MockCloudFeedbackUploader]：测试用，内存态记录调用次数
///
/// UI 调用点：[FeedbackScreen] 提交反馈后，在 `feedbackRepository.save()` 之后
/// 调用 `cloudFeedbackUploader?.upload(payload)`，不 await 或 catch 后静默吞掉。
abstract class CloudFeedbackUploader {
  /// 上传一条匿名反馈到云端。
  ///
  /// 语义：fire-and-forget。
  /// - 实现内部应 catch 所有异常，仅 debugPrint 日志，不抛出
  /// - 未同意云端采集时，实现应静默跳过
  /// - 网络失败 / Function 返回 ok:false / 超时，都不影响调用方
  Future<void> upload(CloudFeedbackPayload payload);
}
