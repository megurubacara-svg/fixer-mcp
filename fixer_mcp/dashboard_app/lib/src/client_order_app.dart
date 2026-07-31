import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_localizations.dart';
import 'architect_cockpit.dart';
import 'client_order_repository.dart';
import 'dashboard_repository.dart';
import 'dashboard_view.dart';

const _clientBlue = Color(0xFF315CF6);
const _clientInk = Color(0xFF172033);
const _clientMuted = Color(0xFF68738A);
const _clientBorder = Color(0xFFE3E7F0);
const _clientCanvas = Color(0xFFF7F8FC);
const _architectAccountEmail = 'architect@example.com';

bool _isArchitectAccount(ClientIdentity identity) {
  final email = identity.email.trim().toLowerCase();
  return email == _architectAccountEmail || email.contains('architect');
}

class ClientOrderApp extends StatefulWidget {
  const ClientOrderApp({
    super.key,
    this.repository,
    this.role = 'client',
    this.userRole,
    this.dashboardRepository,
    this.architectCockpitRepository,
    this.localeController,
  });

  final ClientOrderRepository? repository;
  final Object? role;
  final Object? userRole;
  final DashboardRepository? dashboardRepository;
  final ArchitectCockpitRepository? architectCockpitRepository;
  final AppLocaleController? localeController;

  @override
  State<ClientOrderApp> createState() => _ClientOrderAppState();
}

class _ClientOrderAppState extends State<ClientOrderApp> {
  late final AppLocaleController _localeController;
  late final bool _ownsLocaleController;
  late String _activeRole;

  @override
  void initState() {
    super.initState();
    _localeController = widget.localeController ?? AppLocaleController();
    _ownsLocaleController = widget.localeController == null;
    _activeRole = _normalizeRole(widget.userRole ?? widget.role);
    if (_activeRole.isEmpty) {
      _activeRole = 'client';
    }
  }

  void _handleRoleChanged(String role) {
    setState(() => _activeRole = _normalizeRole(role));
  }

  @override
  void dispose() {
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientRepository = widget.repository ?? BridgeClientOrderRepository();
    final effectiveRole = _activeRole.isEmpty ? 'architect' : _activeRole;
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) => AppLocaleScope(
        notifier: _localeController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppLocalizations.of(context).clientWorkspace,
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: _clientTheme(),
          home: RbacNavigationGuard(
            role: effectiveRole,
            clientView: ClientOrderRouter(
              repository: clientRepository,
              onRoleChanged: _handleRoleChanged,
            ),
            architectView: FixerAppShell(
              role: effectiveRole,
              onRoleChanged: _handleRoleChanged,
              clientView: ClientOrderRouter(
                repository: clientRepository,
                onRoleChanged: _handleRoleChanged,
              ),
              dashboardRepository: widget.dashboardRepository,
              architectCockpitRepository: widget.architectCockpitRepository,
            ),
          ),
        ),
      ),
    );
  }
}

/// The roles understood by the client-facing application shell.
enum RbacRole { client, architect }

typedef UserRole = RbacRole;

/// Selects the smallest surface available to the authenticated role.
///
/// The role is intentionally supplied by the authenticated application entry
/// point rather than inferred from navigation state. Unknown roles fail
/// closed and never receive the architect surface.
class RbacNavigationGuard extends StatelessWidget {
  const RbacNavigationGuard({
    super.key,
    this.role,
    this.userRole,
    this.child,
    this.clientView,
    this.clientDashboard,
    this.architectView,
    this.architectShell,
    this.deniedView,
  });

  final Object? role;
  final Object? userRole;
  final Widget? child;
  final Widget? clientView;
  final Widget? clientDashboard;
  final Widget? architectView;
  final Widget? architectShell;
  final Widget? deniedView;

  @override
  Widget build(BuildContext context) {
    final normalizedRole = _normalizeRole(role ?? userRole);
    return switch (normalizedRole) {
      'client' =>
        clientView ?? clientDashboard ?? child ?? const RbacAccessDeniedView(),
      'architect' => architectView ?? architectShell ?? const FixerAppShell(),
      _ => deniedView ?? const RbacAccessDeniedView(),
    };
  }
}

/// The architect-only application chrome and cockpit route.
class FixerAppShell extends StatefulWidget {
  const FixerAppShell({
    super.key,
    this.role = 'architect',
    this.child,
    this.clientView,
    this.onRoleChanged,
    this.dashboardRepository,
    this.architectCockpitRepository,
  });

  final Object? role;
  final Widget? child;
  final Widget? clientView;
  final ValueChanged<String>? onRoleChanged;
  final DashboardRepository? dashboardRepository;
  final ArchitectCockpitRepository? architectCockpitRepository;

  @override
  State<FixerAppShell> createState() => _FixerAppShellState();
}

class _FixerAppShellState extends State<FixerAppShell> {
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = _normalizeRole(widget.role);
  }

  @override
  void didUpdateWidget(covariant FixerAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextRole = _normalizeRole(widget.role);
    if (nextRole != _normalizeRole(oldWidget.role) && nextRole != _role) {
      _role = nextRole;
    }
  }

  void _setRole(String? role) {
    if (role == null || role == _role) return;
    setState(() => _role = role);
    widget.onRoleChanged?.call(role);
  }

  @override
  Widget build(BuildContext context) {
    final architectSurface =
        widget.child ??
        DashboardShell(
          repository: widget.dashboardRepository ?? BridgeDashboardRepository(),
          architectCockpitRepository: widget.architectCockpitRepository,
        );
    final body = _role == 'client'
        ? widget.clientView ?? const RbacAccessDeniedView()
        : _role == 'architect'
        ? architectSurface
        : const RbacAccessDeniedView();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).fixerWorkspace),
        actions: [
          _RoleBadge(role: _role),
          const SizedBox(width: 8),
          const LanguageSwitcher(compact: true),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _role == 'client' || _role == 'architect' ? _role : null,
                hint: Text(AppLocalizations.of(context).switchRole),
                onChanged: _setRole,
                items: [
                  DropdownMenuItem(
                    value: 'architect',
                    child: Text(AppLocalizations.of(context).architect),
                  ),
                  DropdownMenuItem(
                    value: 'client',
                    child: Text(AppLocalizations.of(context).client),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.status(role);
    return Semantics(
      label: '${l10n.currentRole}: ${l10n.status(role)}',
      child: Chip(
        avatar: const Icon(Icons.verified_user_outlined, size: 16),
        label: Text(l10n.role(label)),
      ),
    );
  }
}

class RbacAccessDeniedView extends StatelessWidget {
  const RbacAccessDeniedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context).isRussian
            ? 'У вашей учётной записи нет доступа к этому рабочему пространству.'
            : 'Your account is not authorized for this workspace.',
      ),
    );
  }
}

String _normalizeRole(Object? value) {
  final raw = value is RbacRole ? value.name : value?.toString();
  return raw?.trim().toLowerCase() ?? '';
}

ThemeData _clientTheme() {
  final base = FixerAppTheme.light();
  final scheme = ColorScheme.fromSeed(
    seedColor: _clientBlue,
    brightness: Brightness.light,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: _clientCanvas,
    canvasColor: _clientCanvas,
    textTheme: base.textTheme.apply(fontFamily: 'Arial'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: _clientInk,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _clientBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _clientBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _clientBlue, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _clientBorder),
      ),
    ),
  );
}

class ClientOrderRouter extends StatefulWidget {
  const ClientOrderRouter({
    super.key,
    required this.repository,
    this.onRoleChanged,
  });

  final ClientOrderRepository repository;
  final ValueChanged<String>? onRoleChanged;

  @override
  State<ClientOrderRouter> createState() => _ClientOrderRouterState();
}

class _ClientOrderRouterState extends State<ClientOrderRouter> {
  ClientIdentity? _identity;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final restorer = widget.repository is ClientSessionRestorer
        ? widget.repository as ClientSessionRestorer
        : null;
    if (restorer == null) return;
    ClientIdentity? identity;
    try {
      identity = await restorer.restoreSession();
    } on Object {
      return;
    }
    if (!mounted || _identity != null || identity == null) return;
    setState(() => _identity = identity);
  }

  void _signedIn(ClientIdentity identity) {
    setState(() => _identity = identity);
  }

  void _signedOut() {
    widget.repository.logout();
    setState(() => _identity = null);
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: identity == null
          ? ClientLoginScreen(
              key: const ValueKey('client-login'),
              repository: widget.repository,
              onSignedIn: _signedIn,
            )
          : ClientDashboardView(
              key: const ValueKey('client-dashboard'),
              identity: identity,
              repository: widget.repository,
              onSignOut: _signedOut,
            ),
    );
  }
}

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
  });

  final ClientOrderRepository repository;
  final ValueChanged<ClientIdentity> onSignedIn;

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final identity = await widget.repository.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) widget.onSignedIn(identity);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [LanguageSwitcher(compact: true)]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final form = _LoginForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  error: _error,
                  loading: _loading,
                  onSubmit: _login,
                );
                return compact
                    ? Column(children: [_LoginIntro(), form])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _LoginIntro()),
                          const SizedBox(width: 72),
                          SizedBox(width: 360, child: form),
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _clientBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.loginIntroTitle,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: _clientInk,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.loginIntroSubtitle,
            style: TextStyle(color: _clientMuted, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.loginTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(l10n.loginSubtitle, style: TextStyle(color: _clientMuted)),
              const SizedBox(height: 26),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  hintText: l10n.emailHint,
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? l10n.validEmail
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(labelText: l10n.password),
                validator: (value) => value == null || value.isEmpty
                    ? l10n.requiredPassword
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.signIn),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientDashboardView extends StatelessWidget {
  const ClientDashboardView({
    super.key,
    required this.identity,
    required this.repository,
    required this.onSignOut,
  });

  final ClientIdentity identity;
  final ClientOrderRepository repository;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ClientScaffold(
      identity: identity,
      selected: 'Dashboard',
      onOrders: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/orders'),
          builder: (_) => ClientOrdersScreen(
            identity: identity,
            repository: repository,
            onSignOut: onSignOut,
          ),
        ),
      ),
      onSignOut: onSignOut,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.greeting(identity.displayName),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _clientInk,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.latestWorkspace,
                      style: TextStyle(color: _clientMuted, fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    FutureBuilder<List<ClientOrderRecord>>(
                      future: repository.loadOrders(),
                      builder: (context, snapshot) {
                        final orders =
                            snapshot.data ?? const <ClientOrderRecord>[];
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _MetricCard(
                              label: l10n.totalOrders,
                              value: '${orders.length}',
                              icon: Icons.folder_copy_outlined,
                              color: _clientBlue,
                            ),
                            _MetricCard(
                              label: l10n.inProgress,
                              value:
                                  '${orders.where((order) => order.status != 'draft').length}',
                              icon: Icons.bolt_outlined,
                              color: const Color(0xFF9B5DE5),
                            ),
                            _MetricCard(
                              label: l10n.draftBriefs,
                              value:
                                  '${orders.where((order) => order.status == 'draft').length}',
                              icon: Icons.edit_note_outlined,
                              color: const Color(0xFF00A896),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.recentOrders,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _clientInk,
                              ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(name: '/orders'),
                              builder: (_) => ClientOrdersScreen(
                                identity: identity,
                                repository: repository,
                                onSignOut: onSignOut,
                              ),
                            ),
                          ),
                          child: Text(l10n.viewAll),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RecentOrders(
                      repository: repository,
                      identity: identity,
                      wide: wide,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compatibility alias for callers that used the original screen name.
typedef ClientDashboardScreen = ClientDashboardView;

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({
    super.key,
    required this.identity,
    required this.repository,
    required this.onSignOut,
  });

  final ClientIdentity identity;
  final ClientOrderRepository repository;
  final VoidCallback onSignOut;

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  late Future<List<ClientOrderRecord>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.loadOrders();
  }

  void _reload() {
    setState(() {
      _orders = widget.repository.loadOrders();
    });
  }

  Future<void> _createOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: '/orders/new'),
        builder: (_) => CreateOrderScreen(repository: widget.repository),
      ),
    );
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ClientScaffold(
      identity: widget.identity,
      selected: 'Orders',
      onOrders: () {},
      onSignOut: widget.onSignOut,
      body: FutureBuilder<List<ClientOrderRecord>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _OrdersError(
              message: _friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final orders = snapshot.data ?? const <ClientOrderRecord>[];
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 16,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.orders,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _clientInk,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.productBriefs,
                              style: TextStyle(
                                color: _clientMuted,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _createOrder,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.newOrder),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: orders.isEmpty
                        ? _EmptyOrders(onCreate: _createOrder)
                        : Column(
                            children: orders
                                .map(
                                  (order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _OrderTile(
                                      order: order,
                                      onTap: () => _openOrder(
                                        context,
                                        order,
                                        widget.repository,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, required this.repository});

  final ClientOrderRepository repository;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

/// Compatibility alias for callers that used the original screen name.
typedef NewOrderScreen = CreateOrderScreen;

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final budget = double.parse(
      _budgetController.text.trim().replaceAll(',', '.'),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createOrderWithBudget(
        projectDescription: _descriptionController.text.trim(),
        budgetCents: (budget * 100).round(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newOrder), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.createProductBrief,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _clientInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.createBriefSubtitle,
                    style: TextStyle(color: _clientMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 9,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: l10n.productBrief,
                      alignLabelWithHint: true,
                      hintText: l10n.productBriefHint,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.addShortBrief
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.budget,
                      hintText: l10n.budgetHint,
                      prefixText: '\$ ',
                    ),
                    validator: (value) {
                      final normalized = value?.trim().replaceAll(',', '.');
                      final parsed = double.tryParse(normalized ?? '');
                      return parsed == null || !parsed.isFinite || parsed < 0
                          ? l10n.validBudget
                          : null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.send_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_saving ? l10n.saving : l10n.createOrder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.repository,
  });

  final int orderId;
  final ClientOrderRepository repository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<ClientOrderDetail> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.loadOrderDetail(widget.orderId);
  }

  void _reload() {
    setState(() {
      _detail = widget.repository.loadOrderDetail(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderDetails),
        leading: const BackButton(),
      ),
      body: FutureBuilder<ClientOrderDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _OrdersError(
              message: _friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return _OrdersError(message: l10n.unavailableOrderDetails);
          }
          return _OrderDetailContent(
            detail: detail,
            repository: widget.repository,
            onRevisionSubmitted: _reload,
          );
        },
      ),
    );
  }
}

class _OrderDetailContent extends StatelessWidget {
  const _OrderDetailContent({
    required this.detail,
    required this.repository,
    required this.onRevisionSubmitted,
  });

  final ClientOrderDetail detail;
  final ClientOrderRepository repository;
  final VoidCallback onRevisionSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = detail.order;
    final summary = detail.latestResultSummary ?? order.latestResultSummary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _clientInk,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatusPill(order.status),
                  if (order.budgetCents > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      l10n.formattedBudget(l10n.formatMoney(order.budgetCents)),
                      style: const TextStyle(color: _clientMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.projectBrief,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(order.projectDescription),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.latestResult,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        summary ?? l10n.noResult,
                        style: TextStyle(
                          color: summary == null ? _clientMuted : _clientInk,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _RevisionHistory(revisions: detail.revisions),
              const SizedBox(height: 16),
              _SubmitRevisionForm(
                repository: repository,
                orderId: order.id!,
                onSubmitted: onRevisionSubmitted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevisionHistory extends StatelessWidget {
  const _RevisionHistory({required this.revisions});

  final List<ClientRevisionRecord> revisions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.revisionHistory,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (revisions.isEmpty)
              Text(l10n.noRevisions, style: TextStyle(color: _clientMuted))
            else
              ...revisions.map(
                (revision) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: _clientBlue.withAlpha(18),
                    child: Text('${revision.revisionNumber}'),
                  ),
                  title: Text(
                    revision.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_formatDate(revision.updatedAt)),
                  trailing: _StatusPill(revision.status),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmitRevisionForm extends StatefulWidget {
  const _SubmitRevisionForm({
    required this.repository,
    required this.orderId,
    required this.onSubmitted,
  });

  final ClientOrderRepository repository;
  final int orderId;
  final VoidCallback onSubmitted;

  @override
  State<_SubmitRevisionForm> createState() => _SubmitRevisionFormState();
}

class _SubmitRevisionFormState extends State<_SubmitRevisionForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.submitRevision(
        orderId: widget.orderId,
        description: _controller.text.trim(),
      );
      if (!mounted) return;
      _controller.clear();
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).revisionSubmitted)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.submitRevisionTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.submitRevisionSubtitle,
                style: TextStyle(color: _clientMuted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.revisionDetails,
                  alignLabelWithHint: true,
                  hintText: l10n.revisionHint,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.addRevisionDetails
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _submitting ? l10n.submitting : l10n.submitRevision,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openOrder(
  BuildContext context,
  ClientOrderRecord order,
  ClientOrderRepository repository,
) {
  final orderId = order.id;
  if (orderId == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/orders/$orderId'),
      builder: (_) =>
          OrderDetailScreen(orderId: orderId, repository: repository),
    ),
  );
}

class _ClientScaffold extends StatelessWidget {
  const _ClientScaffold({
    required this.identity,
    required this.selected,
    required this.onOrders,
    required this.onSignOut,
    required this.body,
  });

  final ClientIdentity identity;
  final String selected;
  final VoidCallback onOrders;
  final VoidCallback onSignOut;
  final Widget body;

  bool get _isArchitect => _isArchitectAccount(identity);

  void _openArchitectCockpit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/architect-cockpit'),
        builder: (_) => ArchitectCockpitScreen(
          repository: BridgeArchitectCockpitRepository(),
        ),
      ),
    );
  }

  void _openFixerProjects(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/fixer-projects'),
        builder: (_) => DashboardShell(
          repository: BridgeDashboardRepository(),
          architectCockpitRepository: BridgeArchitectCockpitRepository(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArch = _isArchitect;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isArch ? Icons.architecture : Icons.auto_awesome,
              color: _clientBlue,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isArch
                    ? (l10n.isRussian
                          ? 'Рабочее пространство Архитектора'
                          : 'Architect Workspace')
                    : l10n.clientWorkspace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isArch)
            TextButton.icon(
              onPressed: () => _openArchitectCockpit(context),
              icon: const Icon(Icons.merge_type_outlined, size: 18),
              label: Text(
                l10n.isRussian ? 'Клиентская фабрика' : 'Client Factory',
              ),
            ),
          const LanguageSwitcher(compact: true),
          PopupMenuButton<String>(
            tooltip: l10n.account,
            onSelected: (value) {
              if (value == 'logout') {
                onSignOut();
              } else if (value == 'architect_cockpit') {
                _openArchitectCockpit(context);
              } else if (value == 'fixer_projects') {
                _openFixerProjects(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  identity.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isArch) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'architect_cockpit',
                  child: Row(
                    children: [
                      const Icon(Icons.merge_type_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isRussian
                            ? 'Клиентская фабрика / Ветки'
                            : 'Architect Cockpit',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'fixer_projects',
                  child: Row(
                    children: [
                      const Icon(Icons.hub_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isRussian
                            ? '${l10n.codexHub} & Нетраннеры'
                            : 'Fixer Projects',
                      ),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text(l10n.signOut(identity.displayName)),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _clientBlue.withAlpha(24),
                child: Text(
                  _initials(identity.displayName),
                  style: const TextStyle(
                    color: _clientBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected == 'Orders'
                ? 1
                : selected == 'ArchitectCockpit'
                ? 2
                : selected == 'FixerProjects'
                ? 3
                : 0,
            onDestinationSelected: (index) {
              if (index == 1 && selected != 'Orders') {
                onOrders();
              } else if (index == 2) {
                _openArchitectCockpit(context);
              } else if (index == 3) {
                _openFixerProjects(context);
              }
            },
            labelType: NavigationRailLabelType.all,
            leading: const SizedBox(height: 20),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view),
                label: Text(l10n.isRussian ? 'Панель' : 'Dashboard'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
                label: Text(l10n.orders),
              ),
              if (isArch) ...[
                NavigationRailDestination(
                  icon: const Icon(Icons.merge_type_outlined),
                  selectedIcon: const Icon(Icons.merge_type),
                  label: Text(l10n.architectCockpit),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.hub_outlined),
                  selectedIcon: const Icon(Icons.hub),
                  label: Text(l10n.projects),
                ),
              ],
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ignore: unused_element
abstract class _LegacyMetricCard extends StatelessWidget {
  const _LegacyMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /*
  @override
  Widget build(BuildContext context) => SizedBox(width: 230, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: _clientInk)), Text(label, style: const TextStyle(color: _clientMuted))])])));
}

}
*/
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _clientInk,
                          ),
                    ),
                    Text(label, style: const TextStyle(color: _clientMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({
    required this.repository,
    required this.identity,
    required this.wide,
  });
  final ClientOrderRepository repository;
  final ClientIdentity identity;
  final bool wide;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ClientOrderRecord>>(
    future: repository.loadOrders(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      if (snapshot.hasError) {
        return _OrdersError(message: _friendlyError(snapshot.error!));
      }
      final orders = snapshot.data ?? const <ClientOrderRecord>[];
      if (orders.isEmpty) {
        return _EmptyOrders(
          onCreate: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              settings: const RouteSettings(name: '/orders/new'),
              builder: (_) => NewOrderScreen(repository: repository),
            ),
          ),
        );
      }
      return Card(
        child: Column(
          children: orders
              .take(wide ? 5 : 3)
              .map(
                (order) => _OrderTile(
                  order: order,
                  compact: true,
                  onTap: () => _openOrder(context, order, repository),
                ),
              )
              .toList(),
        ),
      );
    },
  );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, this.compact = false, this.onTap});
  final ClientOrderRecord order;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 20 : 22,
      vertical: compact ? 6 : 12,
    ),
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: _clientBlue.withAlpha(18),
      child: const Icon(Icons.description_outlined, color: _clientBlue),
    ),
    title: Text(
      order.title,
      style: const TextStyle(fontWeight: FontWeight.w800, color: _clientInk),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        compact ? _formatDate(order.updatedAt) : order.description,
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    trailing: _StatusPill(order.status),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (background, color) = switch (status) {
      'completed' ||
      'approved' => (const Color(0xFFE3F5EC), const Color(0xFF287A57)),
      'in_progress' ||
      'revision_submitted' ||
      'submitted' => (const Color(0xFFE6EEFF), _clientBlue),
      'review' => (const Color(0xFFF2EAFE), const Color(0xFF7A43B6)),
      'failed' ||
      'rejected' => (const Color(0xFFFFE7E7), const Color(0xFFB33A3A)),
      _ => (const Color(0xFFFFF3D8), const Color(0xFF8A681D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        AppLocalizations.of(context).status(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(42),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: _clientMuted),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).noOrdersYet,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _clientInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).noOrdersMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: _clientMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).createFirstOrder),
          ),
        ],
      ),
    ),
  );
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: _clientMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).tryAgain),
            ),
          ],
        ],
      ),
    ),
  );
}

String _friendlyError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  return words.isEmpty
      ? '?'
      : words.take(2).map((word) => word[0].toUpperCase()).join();
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
