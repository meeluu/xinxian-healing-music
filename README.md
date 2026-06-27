# 心弦 XinXian

## Project Epsilon：自然语言驱动的频段特定疗愈音乐生成系统

心弦是一款基于 Flutter 的跨端 AI 疗愈音乐 Demo，支持 Web 网页端与移动端 App。用户输入当下心境后，系统生成情绪画像、音乐参数，并播放匹配的本地疗愈音频素材，形成“自然语言 → 情绪解析 → 音乐方案 → 音频体验 → 用户反馈”的完整闭环。

> 初赛 Demo 当前以 Web 端体验为主。

## 当前进度

- **初赛 Web Demo 闭环已完成**：心境输入 → 情绪解析 → 疗愈方案 → 音频播放 → 用户反馈全链路可体验。
- **已部署至 Netlify 自定义域名**：<https://www.xinxian-music.xyz>
- **移动端布局修复已完成**：针对移动端字体缩放导致的行距过大、组件尺寸异常完成修复，桌面端布局保持不变。
- **Translation Pipeline M1 已完成**：抽象核心模型与 Port（MoodAnalyzerPort / MusicFeatureExtractorPort / AudioGenerationPort / AudioPostProcessorPort / FeedbackRepository / ExperimentAssigner），HealingMusicPlan 重构为聚合根，UI 通过 HealingPipeline 编排器获取方案，对齐正式工程链路分层。
- **Translation Pipeline M2 已完成**：引入 ListeningSession 与实验分组结构，ListeningSessionRecorder Port 负责会话生命周期记录，每次体验会形成一条完整的内存态 ListeningSession，为后续消融实验和反馈数据库做准备。
- **sessionId 已贯穿全链路**：在 HealingPipeline.run(text) 入口生成，依次写入 MoodInput → HealingMusicPlan → FeedbackRecord → ListeningSession，保证一次体验的输入、方案、聆听时长、反馈可被同一条 sessionId 串联。
- **当前 ExperimentVariant 默认 custom**：MockExperimentAssigner 当前恒返回 custom，M2 仅记录分组字段不启用消融分支，后续可扩展为 custom / generic / control 三组对比。
- **当前仍使用 mock 实现**：情绪解析（mock 关键词规则）、音频生成（mock 本地素材）、音频后处理（直通）、会话记录（内存态）均为本地模拟，未接入真实 LLM / 音乐生成模型 / DSP 后处理 / 数据库。后续替换 `mock_pipeline_factory` 的装配即可切换到真实链路，UI 代码无需改动。

## 一、项目背景

当下 18-30 岁青年群体普遍面临备考压力、职场焦虑、睡眠困扰、情绪低落、精神内耗等心理亚健康问题。传统心理咨询存在时间、经济和心理门槛，而通用歌单、白噪音 App、脑波音频产品大多采用固定内容推荐，难以匹配用户当下具体而细腻的情绪状态。

心弦希望探索一种更个性化的情绪陪伴方式：用户只需要输入真实心境描述，系统就能根据文本中的情绪线索生成对应的音乐情绪画像和疗愈音乐参数，为用户提供辅助放松、睡前舒缓、正念陪伴和情绪调节体验。

> 注意：本项目定位为情绪调节与正念放松工具，不替代专业医疗、心理诊断或心理治疗。

## 二、目标用户与使用场景

目标用户：

- 18-30 岁学生与青年职场人
- 面临备考、加班、失眠、情绪低落、关系压力的人群
- 有正念冥想、睡前放松、自我情绪疏导需求的人群

典型场景：

- 睡前脑子停不下来，希望获得舒缓音频
- 备考或工作压力大，希望快速放松
- 情绪低落或内耗时，希望获得陪伴式音乐体验
- 想通过文字记录心境，并得到个性化音乐反馈

## 三、Demo 功能流程

当前初赛 Demo 已实现完整体验闭环：

1. 用户输入心境描述
2. 本地 mock 情绪解析
3. 生成情绪画像
4. 生成疗愈音乐参数
5. 展示 BPM、基准频率、脑波倾向、推荐乐器、噪音层、和声色彩
6. 播放本地音频素材 `music/music_01.mp3`
7. 用户提交体验反馈

流程示意：

```
自然语言心境输入
  → 情绪画像生成
  → 音乐参数映射
  → 疗愈音频播放
  → 用户反馈采集
```

## 四、当前已实现能力

- Flutter Web 可运行 Demo
- 响应式页面布局，适配桌面端和移动端宽度
- 心境输入页
- 情绪解析动画页
- 疗愈方案展示页
- 真实本地音频播放页
- 用户反馈表单
- 6 套情绪模板
- 关键词驱动的本地情绪解析
- BPM、432Hz、Alpha / Theta 等音乐参数展示
- 推荐乐器、和声色彩、噪音层展示
- 基于 `just_audio` 的本地音频播放
- 播放 / 暂停、进度条、时长显示、播放完成重播
- 浅色疗愈风 UI 与轻量动效

## 五、技术架构

当前 Demo 技术链路：

1. 前端应用：Flutter
2. 情绪解析层：本地 mock 关键词规则
3. 音乐参数映射层：情绪模板 → BPM / 频率 / 乐器 / 和声 / 噪音层
4. 音频体验层：本地音频素材播放
5. 反馈采集层：本地状态表单
6. 会话记录层：ListeningSessionRecorder Port，内存态记录每次体验的完整生命周期（begin / updateListening / attachFeedback）

sessionId 流转：在 HealingPipeline.run(text) 入口生成（时间戳 base36 + 随机后缀），依次写入 MoodInput → HealingMusicPlan → FeedbackRecord → ListeningSession，保证一次体验的输入、方案、聆听时长、反馈可被同一条 sessionId 串联。

消融分组扩展点：ExperimentVariant 枚举已定义 custom / generic / control 三组，当前 MockExperimentAssigner 恒返回 custom；后续启用消融实验时，只需替换 ExperimentAssigner 实现按策略分组，ListeningSession 可按 variant 筛选进行对比分析，UI 与 Pipeline 代码无需改动。

未来完整技术链路：

1. Flutter Web + App 跨端前端
2. LLM 自然语言情绪解析
3. 音乐心理特征标签提取
4. AI 音乐生成模型
5. 白噪音 / 粉红噪音 / EQ / 淡入淡出等 DSP 后处理
6. 用户反馈数据库
7. 通用音乐与定制音乐的消融对比实验

## 六、当前 Demo 中使用 mock 的部分

当前版本是初赛可体验 Demo，因此以下模块暂时使用本地模拟：

- 情绪解析暂时使用关键词规则，不调用真实 LLM
- 音乐参数由本地模板生成
- AI 音乐生成模型暂未接入
- DSP 音频后处理暂未真实执行
- 用户反馈暂未接入数据库
- 会话记录（ListeningSession）暂存内存，重启后丢失
- 当前 6 套情绪模板暂时共用 `music/music_01.mp3`

这些 mock 模块均已按可替换方式组织，后续可以逐步替换为真实 AI 服务和后端能力。

## 七、项目价值

社会价值：
为年轻人提供低门槛、轻量化的情绪陪伴和辅助放松入口，降低正念音乐体验的使用门槛。

工程价值：
探索从自然语言到音乐参数再到音频体验的自动化链路，为个性化音频生成产品提供原型验证。

科研价值：
后续可结合心理量表、用户反馈、生理数据，设计“通用音乐 vs 定制化音乐”的对比实验，量化个性化音乐对情绪调节体验的影响。

商业价值：
可拓展至睡眠放松、正念冥想、校园心理支持、企业 EAP 员工关怀、AI 内容生成等场景。

## 八、技术栈

- Flutter
- Dart
- just_audio
- Flutter Web
- 本地音频 assets

## 九、运行方式

环境要求：已安装 Flutter SDK（建议 3.12+），Web 端运行需配置 Chrome 浏览器。

安装依赖：

```bash
flutter pub get
```

静态检查与单元测试：

```bash
flutter analyze
flutter test
```

以 Web 端运行 Demo（推荐）：

```bash
flutter run -d chrome
```

构建 Web 产物：

```bash
flutter build web
```

以移动端运行（需连接模拟器或真机）：

```bash
flutter run
```

## 十、项目结构

```
lib/
├── main.dart                      # 应用入口与主题配置
├── models/                        # 数据模型（情绪画像、音乐方案）
├── data/                          # 本地 mock 情绪模板
├── services/                      # 本地情绪解析服务
├── screens/                       # 五个核心页面
│   ├── home_screen.dart           # 心境输入页
│   ├── analysis_screen.dart       # 情绪解析动画页
│   ├── plan_screen.dart           # 疗愈方案展示页
│   ├── player_screen.dart         # 音频播放页
│   └── feedback_screen.dart       # 用户反馈页
├── theme/                         # 配色与主题
└── widgets/                       # 通用组件（卡片、芯片、输入框、呼吸光晕等）
music/
└── music_01.mp3                   # 本地疗愈音频素材
```

## 十一、平台支持与初赛提交说明

### 当前初赛以 Web Demo 为主

初赛提交以 **Web Demo** 为主要体验入口。执行 `flutter build web --release` 后，产物位于 `build/web/`，可作为静态网站直接部署（Netlify Drop / Vercel / GitHub Pages 等），无需后端服务。

部署后建议验证的体验闭环：心境输入 → 情绪解析 → 疗愈方案 → 进入播放页 → 点击播放按钮听到音频 → 进度条推进 → 完成体验去反馈。

### Android 构建兼容性说明

Android 构建当前存在**上游插件与 Gradle 9 的兼容性问题**，暂不作为初赛阻塞项：

- 项目使用 Flutter 3.44.4 stable，其模板生成的 Android 工具链为 Gradle 9.1.0 + Android Gradle Plugin 9.0.1 + Kotlin 2.3.20。
- 依赖 `just_audio`（及其传递依赖 `audio_session`）的 Android 构建脚本自带旧版 AGP 8.5.2，该版本内部引用了 `org.gradle.util.VersionNumber`，而该类在 Gradle 9.0 中已被移除，导致 Android 构建时报 `NoClassDefFoundError: org/gradle/util/VersionNumber`。
- `just_audio` / `audio_session` 已是当前最新版本，暂无可升级的修复版本，属于上游插件尚未适配新版 Gradle 的不兼容。
- 该问题**仅影响 Android 构建，完全不影响 Web Demo 的构建与体验**，Web 端音频播放、UI、动效均正常。

### Web / Android 互不影响

Web 与 Android 的构建链路相互独立：Android 的 Gradle 配置不参与 `flutter build web`，Web 产物中已正确包含音频资源（`build/web/assets/music/music_01.mp3`）。因此 Android 暂时无法构建不会影响初赛 Web Demo 的提交与体验。

## 十二、免责声明

本项目为高校竞赛 Demo 原型，定位为情绪调节与正念放松辅助工具，提供的音乐体验不具备医疗诊断或治疗功能，不替代专业心理咨询与医疗建议。如有严重情绪困扰或睡眠障碍，请及时寻求专业医师帮助。
