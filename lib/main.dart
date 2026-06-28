import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/pipeline/cloud/http_cloud_feedback_uploader.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/local/local_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/local/local_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';
import 'package:xinxian_healing_music/pipeline/local/web_preferences_factory.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/llm/mood_analyzer_gateway.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 装配运行时服务（PreferencesPort / 本地仓储 / LLM 同意状态 / Pipeline 网关）。
///
/// 存储层装配策略（重点修复 Web 端 shared_preferences 插件未注册问题）：
/// 1. 优先尝试 [SharedPreferences.getInstance()]（跨平台标准路径）
/// 2. 若失败（MissingPluginException 等）且当前为 Web 平台（kIsWeb），
///    自动 fallback 到 [createWebLocalStoragePrefs()]（直接用 window.localStorage）
/// 3. 非 Web 平台失败则保持默认 mock 实现
///
/// 拆分为独立 try/catch 块，任一步骤失败不影响其他步骤：
/// - storage 装配失败 → 后续都保持默认 mock
/// - sessionRecorder 失败 → feedbackRepository / consentService 仍可继续
/// - feedbackRepository 失败 → consentService 仍可继续
/// - consentService 失败 → gateway 保持 null，activePipeline 保持 mockPipeline
///
/// 每个步骤都有 debugPrint 自检日志，便于 Cloudflare Pages / Netlify 环境下诊断。
/// 失败不静默：日志明确输出失败原因，但 UI 仍可用（回退 mock）。
///
/// 提取为顶层函数便于在测试中直接调用验证装配结果。
Future<void> bootstrapServices() async {
  // ─── 1. PreferencesPort 装配（SharedPreferences 优先，Web 端 fallback localStorage）───
  PreferencesPort? storage;
  bool prefsOk = false;
  bool webFallback = false;

  // 同步到全局诊断变量（供 UI "关于"对话框读取），先重置为未启动状态。
  sharedPrefsReady = null;
  webLocalStorageFallback = null;

  try {
    final prefs = await SharedPreferences.getInstance();
    // 诊断写读：确认 localStorage 可用（Web 端按 origin 隔离）
    await prefs.setString(
      'xinxian.diagnostic',
      'ok-${DateTime.now().millisecondsSinceEpoch}',
    );
    final diag = prefs.getString('xinxian.diagnostic');
    debugPrint('[Startup] SharedPreferences ready: true, diag="$diag"');
    storage = SharedPrefsAdapter(prefs);
    prefsOk = true;
  } catch (e, st) {
    debugPrint('[Startup] SharedPreferences 失败: $e');
    debugPrint('$st');

    // Web 平台 fallback：直接用 dart:html window.localStorage
    // 解决 MissingPluginException(getAll on channel plugins.flutter.io/shared_preferences)
    if (kIsWeb) {
      try {
        storage = createWebLocalStoragePrefs();
        webFallback = true;
        debugPrint(
          '[Startup] Web localStorage fallback 已启用 '
          '(storage type=${storage.runtimeType})',
        );
      } catch (e2, st2) {
        debugPrint('[Startup] Web localStorage fallback 也失败: $e2');
        debugPrint('$st2');
      }
    }
  }

  if (storage == null) {
    debugPrint('[Startup] 全部存储不可用，保持默认 mock 实现');
    debugPrint(
      '[Startup] 自检汇总: prefs=false, webFallback=false, '
      'recorder=${sessionRecorder.runtimeType}, consent=null, pipeline=mock',
    );
    // 同步到全局诊断变量（供 UI "关于"对话框读取）
    sharedPrefsReady = false;
    webLocalStorageFallback = false;
    return;
  }

  // 存储装配成功，同步到全局诊断变量（供 UI "关于"对话框读取）
  sharedPrefsReady = prefsOk;
  webLocalStorageFallback = webFallback;

  // ─── 2. sessionRecorder（独立 try/catch，失败不影响后续）───
  try {
    sessionRecorder = await LocalListeningSessionRecorder.create(storage);
    debugPrint(
      '[Startup] sessionRecorder 装配完成: type=${sessionRecorder.runtimeType}, '
      'loaded=${sessionRecorder.all().length} sessions',
    );
  } catch (e, st) {
    debugPrint('[Startup] sessionRecorder 装配失败，保持 mock: $e');
    debugPrint('$st');
  }

  // ─── 3. feedbackRepository（独立 try/catch）───
  try {
    feedbackRepository = await LocalFeedbackRepository.create(storage);
    debugPrint(
      '[Startup] feedbackRepository 装配完成: type=${feedbackRepository.runtimeType}',
    );
  } catch (e, st) {
    debugPrint('[Startup] feedbackRepository 装配失败，保持 mock: $e');
    debugPrint('$st');
  }

  // ─── 4. llmConsentService（独立 try/catch）───
  try {
    llmConsentService = await LlmConsentService.create(storage);
    debugPrint(
      '[Startup] llmConsentService 装配完成: status=${llmConsentService!.status}',
    );
  } catch (e, st) {
    debugPrint('[Startup] llmConsentService 装配失败，保持 null: $e');
    debugPrint('$st');
  }

  // ─── 5. moodAnalyzerGateway + activePipeline（仅当 consentService 装配成功）───
  if (llmConsentService != null) {
    try {
      moodAnalyzerGateway = MoodAnalyzerGateway(
        llmAnalyzer: const LlmMoodAnalyzer(),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: llmConsentService!,
      );
      activePipeline = buildPipelineWith(moodAnalyzerGateway!);
      debugPrint('[Startup] activePipeline 已切换为带 MoodAnalyzerGateway 的版本');
    } catch (e, st) {
      debugPrint(
        '[Startup] moodAnalyzerGateway 装配失败，activePipeline 保持 mock: $e',
      );
      debugPrint('$st');
    }
  } else {
    debugPrint(
      '[Startup] llmConsentService 为 null，跳过 gateway 装配，activePipeline 保持 mock',
    );
  }

  // ─── 6. cloudFeedbackConsentService（M7 新增，独立 try/catch）───
  try {
    cloudFeedbackConsentService = await CloudFeedbackConsentService.create(
      storage,
    );
    debugPrint(
      '[Startup] cloudFeedbackConsentService 装配完成: '
      'status=${cloudFeedbackConsentService!.status}',
    );
  } catch (e, st) {
    debugPrint('[Startup] cloudFeedbackConsentService 装配失败，保持 null: $e');
    debugPrint('$st');
  }

  // ─── 7. cloudTextConsentService（M7 新增，独立 try/catch）───
  try {
    cloudTextConsentService = await CloudTextConsentService.create(storage);
    debugPrint(
      '[Startup] cloudTextConsentService 装配完成: '
      'status=${cloudTextConsentService!.status}',
    );
  } catch (e, st) {
    debugPrint('[Startup] cloudTextConsentService 装配失败，保持 null: $e');
    debugPrint('$st');
  }

  // ─── 8. cloudFeedbackUploader（M7 新增，依赖 6/7 两个 consent 服务）───
  // 仅当两个 consent 服务都装配成功时才切换为 HTTP 实现，
  // 否则保持默认 MockCloudFeedbackUploader（不发起 HTTP 请求）。
  if (cloudFeedbackConsentService != null && cloudTextConsentService != null) {
    try {
      cloudFeedbackUploader = HttpCloudFeedbackUploader(
        consent: cloudFeedbackConsentService!,
        textConsent: cloudTextConsentService!,
      );
      debugPrint(
        '[Startup] cloudFeedbackUploader 装配完成: '
        'type=${cloudFeedbackUploader.runtimeType}',
      );
    } catch (e, st) {
      debugPrint('[Startup] cloudFeedbackUploader 装配失败，保持 mock: $e');
      debugPrint('$st');
    }
  } else {
    debugPrint('[Startup] cloud consent 服务未就绪，cloudFeedbackUploader 保持 mock');
  }

  // ─── 启动自检汇总（仅 debugPrint，不显示到 UI）───
  final analyzerMode = moodAnalyzerGateway != null ? 'gateway' : 'mock';
  debugPrint('[Startup] ===== 自检汇总 =====');
  debugPrint('[Startup] SharedPreferences ready: $prefsOk');
  debugPrint('[Startup] webLocalStorageFallback: $webFallback');
  debugPrint('[Startup] storage type: ${storage.runtimeType}');
  debugPrint('[Startup] sessionRecorder type: ${sessionRecorder.runtimeType}');
  debugPrint(
    '[Startup] llmConsentService status: ${llmConsentService?.status ?? "null"}',
  );
  debugPrint('[Startup] activePipeline analyzer mode: $analyzerMode');
  debugPrint(
    '[Startup] cloudFeedbackConsentService status: '
    '${cloudFeedbackConsentService?.status ?? "null"}',
  );
  debugPrint(
    '[Startup] cloudTextConsentService status: '
    '${cloudTextConsentService?.status ?? "null"}',
  );
  debugPrint(
    '[Startup] cloudFeedbackUploader type: ${cloudFeedbackUploader.runtimeType}',
  );
  debugPrint('[Startup] ======================');
}

void main() async {
  // shared_preferences 是平台插件，需要初始化 binding
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrapServices();

  runApp(const XinXianApp());
}

class XinXianApp extends StatelessWidget {
  const XinXianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '心弦 · 疗愈音乐',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) {
        // 移动端浏览器/系统字体缩放会被 Flutter Web 隐式拾取并放大所有文字
        // （Text 组件内部使用 MediaQuery.textScalerOf），导致行距与 chip 高度异常巨大。
        // 这里将 textScaler 限制在 [1.0, 1.2]：
        // - 桌面端默认 1.0，clamp 后不变，布局完全不受影响。
        // - 移动端过大缩放被限制在 1.2，恢复正常的行距与组件密度，
        //   同时保留 1.2 倍以内的无障碍放大，不完全禁用辅助功能。
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2),
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE6F1F9),
          onPrimaryContainer: AppColors.primaryDeep,
          secondary: AppColors.teal,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE7F4EF),
          onSecondaryContainer: AppColors.tealDeep,
          surface: AppColors.cardBg,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerHighest: const Color(0xFFF0F5F9),
          error: const Color(0xFFE07A6B),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgBase,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.cardBorder,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x1F6BAED6),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF4FA),
        surfaceTintColor: Colors.transparent,
        labelStyle: const TextStyle(color: AppColors.chipLabelText),
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
