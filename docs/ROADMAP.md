# 心弦 · 项目路线图（ROADMAP）

> 本文档记录心弦项目的阶段划分、各阶段目标与「不做什么」。
> 当前线上状态与已完成事项以 [README.md](../README.md) 为准；本文档聚焦「走向哪里」。
>
> 文档风格：中文、不写营销空话、不写未验证结论、不出现医疗化表达（治疗 / 治愈 / 诊断 / 疗法），
> 不暴露任何 API Key / 服务器密码 / Cloudflare Token。

## 当前阶段

**P4-player-seek-bugfix-1（修复快速舒缓播放页拖动进度条回到 0 秒）**

在 P4-playback-experience-2 已完成的基础上，修复「快速舒缓一下」进入本地音乐播放页后、新用户首次拖动进度条会自动回到 0 秒并从头重新播放的早期遗留 bug。本批为纯前端播放体验修复，不部署、不真实调用 MiniMax、不依赖 R2、不改 AI 歌曲生成链路：

- **根因**：`lib/screens/player_screen.dart` 的 `_ProgressSection.onChangeEnd` 调 `player.seek(target)` 后未 await 且立即清空 `_dragValue`，slider 显示 `positionStream` 旧快照（首次进入≈0）导致视觉回弹到 0；且 `_ProgressSection` 直接调 `player.seek()` 不通知宿主清空 `_completed`，歌曲播完后拖到中间再点播放，`_toggle()` 检测 `processingState==completed` 走 `seek(Duration.zero)+play()` 真正重播。
- **修复**：新增 `lib/utils/play_button_decision.dart` 纯函数 `decidePlayButtonAction`（`replayFromStart / play / pause`），把"自然播完→重播"与"手动 seek→继续"分开（`completed+completedFlag=true→replayFromStart`，`completed+completedFlag=false→play` 不回 0）；`_toggle()` 改用纯函数；`_ProgressSection` 新增 `onSeekStart` 回调清空 `_completed` + `_pendingSeek` 防回弹逻辑（positionStream 确认到达目标前 slider 持续显示目标值，800ms 保护计时器兜底）。
- **修复后行为**：拖到任意位置可继续播放、暂停态拖动保持暂停、播完后拖到中间不强制回 0、切模式 / 定时强制循环态下拖动不回 0；只有点击"重新播放"或在 completed 状态点击播放（未手动 seek）才回 0。
- **不影响范围**：快速舒缓仍只使用本地 `AudioAssetCatalog`，不调 `/api/generate-music`、不调 MiniMax、不扣 P6 额度；`generated_song_player_screen.dart`（AI 歌曲播放页）有相同 seek 模式，按用户要求聚焦快速舒缓页，AI 歌曲播放页留作后续可选跟进，不影响生成链路与三重门保护。
- 保留 P6-quota-guard-1 本地额度保护；保留 4 种播放模式与定时关闭持续播放保证。
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`，`manualTest=true` 保护保留。
- 本批不部署上线，不新增自动调用 / 轮询 / 重试，不引入新依赖。

### 上一阶段（已完成）

**P4-playback-experience-2（AI 歌曲独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证）** 已完成，详见 README 6.22。**P4-conversation-song-flow-1-fix2** 已于 2026-07-24 上线，详见 README 6.21。**P4-conversation-song-flow-1-fix1** 已完成，详见 README 6.20。**P4-conversation-song-flow-1** 已于 2026-07-23 上线，详见 README 6.19。

## 阶段划分

### 短期：安全小范围内测（当前）

- **P4-player-seek-bugfix-1（本批）**：修复快速舒缓播放页首次进入拖动进度条回到 0 秒（`_pendingSeek` 防回弹 + `completedFlag` 分离重播 / 继续）。
- **P4-playback-experience-2（已完成）**：AI 歌曲独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证。
- **P4-conversation-song-flow-1-fix2（已上线）**：low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核。
- **P4-conversation-song-flow-1-fix1（已完成）**：LLM 动态追问 + 歌词贴合度增强 + 快速舒缓纯本地化核查 + 加载文案分阶段。
- **P4-conversation-song-flow-1（已上线）**：多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭。
- **P6-quota-guard-1（已完成）**：浏览器本地每日额度保护 + service 单元测试 + 文档整理。
- 目标：在真实调用仍关闭的前提下，优化 AI 歌曲生成后的播放体验（独立播放页）与本地舒缓播放模式（4 种模式 + 定时持续播放），同时保留成本保护。
- **不做什么**：不打开真实调用、不部署上线、不做付费、不做用户系统、不做 R2 持久化、不做历史歌曲、不做分享链接、不做 4090 部署、不做真实 MiniMax 测试。

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
| P4-player-seek-bugfix-1 | 修复快速舒缓播放页拖动进度条回到 0 秒（`_pendingSeek` 防回弹 + `completedFlag` 分离重播 / 继续） | ✅ 本批完成 |
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
