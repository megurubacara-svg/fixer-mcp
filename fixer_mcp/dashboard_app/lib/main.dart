import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_theme.dart';
import 'src/app_localizations.dart';
import 'src/architect_cockpit.dart';
import 'src/client_order_app.dart';
import 'src/dashboard_repository.dart';
import 'src/dashboard_view.dart';
import 'src/hub/backlog/backlog_repository.dart';
import 'src/hub/fixer_chat/fixer_chat_service.dart';
import 'src/hub/netrunner_thread/netrunner_thread_repository.dart';
import 'src/hub/netrunners/netrunner_repository.dart';
import 'src/hub/overseer/overseer_repository.dart';
import 'src/hub/skills/skills_repository.dart';
import 'src/mission_control/mission_control_repository.dart';

const _manageBundledBackend = bool.fromEnvironment(
  'FIXER_STUDIO_MANAGE_BACKEND',
);
const _fixerStudioRoot = String.fromEnvironment('FIXER_STUDIO_ROOT');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    _manageBundledBackend
        ? const _BackendBootstrap(projectRoot: _fixerStudioRoot)
        : const ClientOrderApp(),
  );
}

class _BackendBootstrap extends StatefulWidget {
  const _BackendBootstrap({required this.projectRoot});

  final String projectRoot;

  @override
  State<_BackendBootstrap> createState() => _BackendBootstrapState();
}

class _BackendBootstrapState extends State<_BackendBootstrap> {
  Process? _backendProcess;
  late Future<void> _ready = _startBackend();

  Future<void> _startBackend() async {
    if (await _backendReady()) return;
    if (widget.projectRoot.trim().isEmpty) {
      throw StateError('The Fixer Studio project root is not configured.');
    }

    final script = File(
      '${widget.projectRoot}/fixer_mcp/scripts/'
      'fixer_studio_backend_service.sh',
    );
    if (!script.existsSync()) {
      throw StateError('Backend launcher not found: ${script.path}');
    }

    final process = await Process.start(script.path, ['run', '$pid']);
    _backendProcess = process;
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    final exited = process.exitCode.then<void>((code) {
      throw StateError('Backend launcher exited with code $code.');
    });
    await Future.any<void>([_waitUntilReady(), exited]);
  }

  Future<void> _waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      if (await _backendReady()) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('The local backend did not become ready in time.');
  }

  Future<bool> _backendReady() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      for (final endpoint in const [
        'http://127.0.0.1:18090/health',
        'http://127.0.0.1:14242/health',
        'http://127.0.0.1:28080/livez',
      ]) {
        final request = await client.getUrl(Uri.parse(endpoint));
        final response = await request.close().timeout(
          const Duration(seconds: 1),
        );
        await response.drain<void>();
        if (response.statusCode != HttpStatus.ok) return false;
      }
      return true;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _retry() {
    _backendProcess?.kill(ProcessSignal.sigterm);
    _backendProcess = null;
    setState(() => _ready = _startBackend());
  }

  @override
  void dispose() {
    _backendProcess?.kill(ProcessSignal.sigterm);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const ClientOrderApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: FixerAppTheme.light(),
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!snapshot.hasError)
                        const CircularProgressIndicator()
                      else
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 52,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      const SizedBox(height: 24),
                      Text(
                        snapshot.hasError
                            ? 'Fixer Studio backend is unavailable'
                            : 'Starting Fixer Studio…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.hasError
                            ? 'Check that Docker is running, then try again.'
                            : 'Preparing the local workspace services.',
                        textAlign: TextAlign.center,
                      ),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FixerDashboardApp extends StatefulWidget {
  const FixerDashboardApp({
    super.key,
    this.repository,
    this.architectCockpitRepository,
    this.localeController,
    this.backlogRepository,
    this.netrunnerExplorerRepository,
    this.fixerChatService,
    this.netrunnerThreadRepository,
    this.skillsRepository,
    this.overseerRepository,
    this.missionControlRepository,
  });

  final DashboardRepository? repository;
  final ArchitectCockpitRepository? architectCockpitRepository;
  final AppLocaleController? localeController;
  final BacklogRepository? backlogRepository;
  final NetrunnerExplorerRepository? netrunnerExplorerRepository;
  final FixerChatService? fixerChatService;
  final NetrunnerThreadRepository? netrunnerThreadRepository;
  final SkillsRepository? skillsRepository;
  final OverseerManagerRepository? overseerRepository;
  final MissionControlRepository? missionControlRepository;

  @override
  State<FixerDashboardApp> createState() => _FixerDashboardAppState();
}

class _FixerDashboardAppState extends State<FixerDashboardApp> {
  late final AppLocaleController _localeController;
  late final bool _ownsLocaleController;

  @override
  void initState() {
    super.initState();
    _localeController = widget.localeController ?? AppLocaleController();
    _ownsLocaleController = widget.localeController == null;
  }

  @override
  void dispose() {
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) => AppLocaleScope(
        notifier: _localeController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppLocalizations.of(context).appTitle,
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: FixerAppTheme.light(),
          home: DashboardShell(
            repository: widget.repository ?? BridgeDashboardRepository(),
            architectCockpitRepository:
                widget.architectCockpitRepository ??
                BridgeArchitectCockpitRepository(),
            backlogRepository: widget.backlogRepository,
            netrunnerExplorerRepository: widget.netrunnerExplorerRepository,
            fixerChatService: widget.fixerChatService,
            netrunnerThreadRepository: widget.netrunnerThreadRepository,
            skillsRepository: widget.skillsRepository,
            overseerRepository: widget.overseerRepository,
            missionControlRepository: widget.missionControlRepository,
          ),
        ),
      ),
    );
  }
}
