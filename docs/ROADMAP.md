# 心弦 · 项目路线图（ROADMAP）

> 本文档记录心弦项目的阶段划分、各阶段目标与「不做什么」。
> 当前线上状态与已完成事项以 [README.md](../README.md) 为准；本文档聚焦「走向哪里」。
>
> 文档风格：中文、不写营销空话、不写未验证结论、不出现医疗化表达（治疗 / 治愈 / 诊断 / 疗法），
> 不暴露任何 API Key / 服务器密码 / Cloudflare Token。

## 当前阶段

**P5-music-metadata-foundation-1（本地音乐元数据基础改造）**

为后续「本地音乐内容库与推荐质量增强」做准备。本批不扩充音乐内容库（仍 5 首本地音频），只把快速舒缓流程中「疗愈方案页」的音乐时长与音乐参数改成与具体音频资产绑定，避免页面写死统一时长。为 `AudioAsset` 新增 `MusicProfile` 元数据结构（tempo / texture / energyCurve / suitableScene / parameterStatus），填入真实测量的 `durationSeconds`，方案页「为什么推荐这段音乐」时长 / 声音特征改为 per-asset 读取（缺失温和兜底），折叠「音乐参数」卡采用「优先 per-asset、回退 plan.features」混合策略。当前参数均为初步占位推断，标为 `preliminary / 待校准`，后续逐首接入真实参数后改 `calibrated`。

- **定位**：元数据结构打通批次，不是内容库扩充，不是推荐算法大改。
- **范围**：仅改快速舒缓本地音乐推荐 / 方案展示相关逻辑；`EmotionToMusicPlanMapper` / `MusicFeatureTags` 不动，`plan.features` 保留作回退。
- **不影响范围**：快速舒缓仍只使用本地 `AudioAssetCatalog` assets，不调 `/api/generate-music`、不调 MiniMax；不改 AI 歌曲生成链路；不修改 `MUSIC_GENERATION_REAL_CALLS_ENABLED`，`manualTest=true` 三重门保留。
- **不做什么**：不把 P5 内容库扩充写成已完成（仍 5 首，仅加元数据结构，未接入真实音乐分析参数）；不使用医疗化表达；未做 R2 / 历史歌曲 / 分享 / 付费 / 用户系统 / 4090 部署。

### 上一阶段（已完成）

**P4-player-seek-refresh-workaround-1（首次进入播放器自动软重建，临时兜底 seek 回 0）** 已完成，详见 README 6.26。**P4-playback-experience-2（AI 歌曲独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证）** 已完成，详见 README 6.22。**P4-conversation-song-flow-1-fix2** 已于 2026-07-24 上线，详见 README 6.21。**P4-conversation-song-flow-1-fix1** 已完成，详见 README 6.20。**P4-conversation-song-flow-1** 已于 2026-07-23 上线，详见 README 6.19。

## 阶段划分

### 短期：安全小范围内测（当前）

- **P5-music-metadata-foundation-1（本批）**：本地音乐元数据基础改造，为 `AudioAsset` 增加 `MusicProfile` + 真实 `durationSeconds`，方案页时长 / 声音特征改为 per-asset，折叠「音乐参数」卡混合策略；不扩充内容库，不大改推荐算法。
- **P4-player-seek-refresh-workaround-1（已完成）**：快速舒缓本地播放页首次进入后自动软重建一次，临时兜底首次 seek 回 0；不是底层 seek 根因最终修复。
- **P4-player-seek-bugfix-3（已完成）**：修复快速舒缓播放页首次 ready 前允许 seek 导致拖动回 0、二次打开正常（seek-ready 门控 + 临时 debug）。
- **P4-player-seek-bugfix-2（已完成）**：修复快速舒缓播放页首次 seek 尚未完成时被 `positionStream` 的 0 拉回（await seek + 延迟确认 + 3 秒兜底）。
- **P4-player-seek-bugfix-1（已完成）**：修复快速舒缓播放页首次进入拖动进度条回到 0 秒（`_pendingSeek` 防回弹 + `completedFlag` 分离重播 / 继续）。
- **P4-playback-experience-2（已完成）**：AI 歌曲独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证。
- **P4-conversation-song-flow-1-fix2（已上线）**：low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核。
- **P4-conversation-song-flow-1-fix1（已完成）**：LLM 动态追问 + 歌词贴合度增强 + 快速舒缓纯本地化核查 + 加载文案分阶段。
- **P4-conversation-song-flow-1（已上线）**：多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭。
- **P6-quota-guard-1（已完成）**：浏览器本地每日额度保护 + service 单元测试 + 文档整理。
- 目标：在真实调用仍关闭的前提下，先打通本地音乐元数据结构，为后续内容库扩充与推荐质量增强做准备，同时保留成本保护。
- **不做什么**：不打开真实调用、不部署上线、不做付费、不做用户系统、不做 R2 持久化、不做历史歌曲、不做分享链接、不做 4090 部署、不做真实 MiniMax 测试、不扩充音乐内容库（仍 5 首）。

### 中期：持久化 · 历史 · 分享 · 用户 · 付费

- **R2 持久化**：把 MiniMax 返回的 audioHex 落地到 Cloudflare R2，生成可长期访问的播放链接，
  替代当前的 `audioDataUrl`（base64 临时播放）方案。
- **历史生成歌曲**：用户可在历史记录里回看 / 重听之前生成的歌（当前仅「快速舒缓一下」有本地历史）。
- **分享链接**：生成可分享的歌曲链接（受版权与成本策略约束）。
- **用户系统**：可选登录 / 跨设备同步（账号体系）。
- **付费 / 会员 / 额度购买**：在本地额度之上叠加云端额度核销，打通商业化最小闭环。
- **不做什么**：不把 Cloudflare 写成最终唯一后端（见长期方向）；不强制登录才能体验核心流程。

### 长期：自有算力 · 自有模型 · 增长 Agent

- **4090 后端迁移**：把音乐生成 worker 从 MiniMax API 迁移到自托管 4090 服务器，
  降低单次生成成本、摆脱第三方配额与计费波动。**Cloudflare 是当前验证环境，4090 是后续迁移方向**。
- **自有音乐模型替换 MiniMax**：在 4090 上部署自有 / 开源音乐生成模型，作为 MiniMax 的替代 provider。
- **小红书 / 社交增长 Agent**：围绕生成内容做外部分享与增长。
- **不做什么**：不在当前阶段引入 4090 部署（4090 服务器暂不部署，作为后续自托管方向）；
  不调用 Mureka API（历史调研未采用）。

## 阶段对照速查

| 阶段 | 主题 | 状态 |
|---|---|---|
| M1–M8.1 | 架构与核心能力（Pipeline / LLM 情绪解析 / 音频匹配 / 云端反馈 / 消融实验） | ✅ 已完成 |
| P1 / P2 / P3 | Web 产品化修复 / Web 体验优化 / 数据与反馈运营 | ✅ 已完成 |
| P4-AI-Music-v1.0 | AI 音乐生成接入（MiniMax 打通 + audioDataUrl 临时播放 + 结果页体验） | ✅ 已完成（默认 REAL_CALLS=false） |
| P6-quota-guard-1 | 本地额度保护与成本安全（首批） | ✅ 已完成 |
| P4-conversation-song-flow-1 | 多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭 | ✅ 已上线（2026-07-23） |
| P4-conversation-song-flow-1-fix1 | LLM 动态追问 + 歌词贴合度增强 + 快速舒缓纯本地化核查 + 加载文案分阶段 | ✅ 已完成 |
| P4-conversation-song-flow-1-fix2 | low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核 | ✅ 已上线（2026-07-24） |
| P4-playback-experience-2 | AI 歌曲独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证 | ✅ 已完成 |
| P4-player-seek-bugfix-1 | 修复快速舒缓播放页拖动进度条回到 0 秒（`_pendingSeek` 防回弹 + `completedFlag` 分离重播 / 继续） | ✅ 已完成 |
| P4-player-seek-bugfix-2 | 修复首次 seek 尚未完成时被 `positionStream` 的 0 拉回（await seek + 延迟确认） | ✅ 已完成 |
| P4-player-seek-bugfix-3 | 修复首次 ready 前允许 seek 导致拖动回 0、二次打开正常（seek-ready 门控） | ✅ 已完成 |
| P4-player-seek-refresh-workaround-1 | 首次进入快速舒缓本地播放页后自动软重建一次，临时兜底首次 seek 回 0 | ✅ 已完成 |
| P5-music-metadata-foundation-1 | 本地音乐元数据基础改造（per-asset 时长 / 声音特征结构打通，参数标 preliminary） | ✅ 本批完成 |
| 中期 | R2 持久化 / 历史生成歌曲 / 分享链接 / 用户系统 / 付费会员 | ⏳ 计划中 |
| 长期 | 4090 后端迁移 / 自有音乐模型 / 增长 Agent | ⏳ 计划中 |

> 说明：原路线图中「P6 = 用户系统」的编号已被本批「P6-quota-guard-1 = 额度保护」占用。
> 用户系统顺延至中期阶段，与持久化 / 付费一并推进。

## 风险与限制

- 当前播放仍是 `audioDataUrl` 临时方案（base64 内嵌），刷新后需重新生成，非持久化资源。
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认 `false`：真实 MiniMax 调用需三重门
 （`MUSIC_GENERATION_PROVIDER=minimax_music` + `MUSIC_GENERATION_REAL_CALLS_ENABLED=true` + 请求体 `manualTest=true`）。
- 本地额度保护仅是**早期内测 / 误点保护**，**不是商业级防刷**：用户清除站点数据、更换浏览器、更换设备后即可绕过重置，不适合作为正式付费系统的唯一额度依据。真正的成本控制仍依赖后端 `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 总开关与未来云端额度核销。
- 后续商业化需要的额度能力（当前全部未做）：云端用户系统、服务端额度校验、订单 / 支付记录、失败不扣次数、风控与异常请求限制。
- Cloudflare Free 计划仅支持 1 条限流规则，`/api/submit-feedback` 限流暂未配置。
