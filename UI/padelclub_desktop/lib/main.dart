import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/localization/language_switcher.dart';
import 'package:padelclub_desktop/core/localization/locale_controller.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/dashboard_page.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'package:padelclub_desktop/features/courts/presentation/screens/court_management_screen.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_management_provider.dart';
import 'package:padelclub_desktop/features/memberships/presentation/screens/membership_management_screen.dart';
import 'package:padelclub_desktop/features/notifications/data/repositories/http_notification_repository.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_provider.dart';
import 'package:padelclub_desktop/features/notifications/presentation/screens/notification_management_screen.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/operations_analytics_provider.dart';
import 'package:padelclub_desktop/features/operations/presentation/screens/audit_trail_screen.dart';
import 'package:padelclub_desktop/features/operations/presentation/screens/provider_readiness_screen.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/orders/presentation/screens/order_management_screen.dart';
import 'package:padelclub_desktop/features/payments/data/repositories/http_payment_repository.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';
import 'package:padelclub_desktop/features/payments/presentation/screens/payments_screen.dart';
import 'package:padelclub_desktop/features/player_experience/data/repositories/http_city_repository.dart';
import 'package:padelclub_desktop/features/player_experience/domain/usecases/get_cities.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/providers/player_experience_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/screens/product_list_screen.dart';
import 'package:padelclub_desktop/features/product/presentation/screens/product_management_screen.dart';
import 'package:padelclub_desktop/features/profile/presentation/screens/profile_screen.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/data/repositories/recommendation_evaluation_repository_impl.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart';
import 'package:padelclub_desktop/features/recommendations/presentation/providers/product_recommendation_provider.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/features/reservations/presentation/screens/reservation_screens.dart';
import 'package:padelclub_desktop/features/returns/presentation/providers/return_requests_provider.dart';
import 'package:padelclub_desktop/features/reviews/presentation/providers/club_review_provider.dart';
import 'package:padelclub_desktop/features/search/presentation/providers/discovery_provider.dart';
import 'package:padelclub_desktop/features/search/presentation/screens/search_screen.dart';
import 'package:padelclub_desktop/features/tournament/presentation/providers/tournament_provider.dart';
import 'package:padelclub_desktop/features/tournament_management/presentation/screens/tournament_management_screen.dart';
import 'package:padelclub_desktop/features/users/presentation/providers/user_provider.dart';
import 'package:padelclub_desktop/features/users/presentation/screens/user_management_screen.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sl.init();
  runApp(const PadelClubBootstrap());
}

/// Shared composition root used by the desktop and mobile distribution targets.
class PadelClubBootstrap extends StatelessWidget {
  const PadelClubBootstrap({
    super.key,
    this.authProvider,
    this.paymentSheetPresenter = const UnavailablePaymentSheet(),
    this.homeRouteBuilder,
  });

  /// An optional authentication provider for runner-level widget tests.
  ///
  /// Production runners omit this and create an [AuthProvider].
  final AuthProvider? authProvider;
  final PaymentSheetPresenter paymentSheetPresenter;

  /// An optional player home route for runner-level widget tests.
  ///
  /// Production runners omit this and use [DashboardPage].
  final WidgetBuilder? homeRouteBuilder;

  @override
  Widget build(BuildContext context) {
    final resolvedAuthProvider = authProvider ?? AuthProvider();
    final recommendationEvaluationDataSource =
        RecommendationEvaluationRemoteDataSourceImpl(
          headersProvider: AuthProvider.authenticatedHeaders,
        );
    final recommendationEvaluationRepository =
        RecommendationEvaluationRepositoryImpl(
          recommendationEvaluationDataSource,
        );
    final getRecommendationEvaluation = GetRecommendationEvaluation(
      recommendationEvaluationRepository,
    );
    final createRecommendationEvaluationRun = CreateRecommendationEvaluationRun(
      recommendationEvaluationRepository,
    );
    final getLatestRecommendationEvaluationRun =
        GetLatestRecommendationEvaluationRun(
          recommendationEvaluationRepository,
        );
    return MultiProvider(
      providers: [
        Provider<PaymentSheetPresenter>.value(value: paymentSheetPresenter),
        Provider<PaymentRepository>(
          create: (_) =>
              HttpPaymentRepository(headers: AuthProvider.authenticatedHeaders),
          dispose: (_, repository) => repository.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: resolvedAuthProvider),
        ChangeNotifierProvider<ReservationProvider>(
          create: (_) => ReservationProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ChangeNotifierProvider<ReturnRequestsProvider>(
          create: (_) => ReturnRequestsProvider.live(),
        ),
        ChangeNotifierProvider<OperationsAnalyticsProvider>(
          create: (_) => OperationsAnalyticsProvider(),
        ),
        ChangeNotifierProvider<RecommendationEvaluationProvider>(
          create: (_) => RecommendationEvaluationProvider(
            getRecommendationEvaluation,
            createRecommendationEvaluationRun,
            getLatestRecommendationEvaluationRun,
          ),
        ),
        ChangeNotifierProvider<RecommendationOperationalReadinessProvider>(
          create: (_) => RecommendationOperationalReadinessProvider(),
        ),
        ChangeNotifierProvider<CourtProvider>(create: (_) => CourtProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(
            HttpNotificationRepository(
              headers: AuthProvider.authenticatedHeaders,
            ),
          ),
          update: (_, auth, notifications) =>
              notifications!..setSession(auth.userId, auth.isAdministrator),
        ),
        ChangeNotifierProvider<ClubReviewProvider>(
          create: (_) => ClubReviewProvider(),
        ),
        ChangeNotifierProvider<TournamentProvider>(
          create: (_) => sl.tournamentProvider,
        ),
        ChangeNotifierProvider<ProductProvider>(
          create: (context) => sl.loggedProductProvider,
        ),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<ProductRecommendationProvider>(
          create: (_) => ProductRecommendationProvider(),
        ),
        ChangeNotifierProvider<DiscoveryProvider>(
          create: (_) => DiscoveryProvider(),
        ),
        ChangeNotifierProvider<PlayerExperienceProvider>(
          create: (_) => PlayerExperienceProvider(
            getCities: GetCities(HttpCityRepository()),
          ),
        ),
      ],
      child: PadelClubApp(homeRouteBuilder: homeRouteBuilder),
    );
  }
}

class PadelClubApp extends StatefulWidget {
  const PadelClubApp({super.key, this.homeRouteBuilder, this.localeController});

  final WidgetBuilder? homeRouteBuilder;
  final LocaleController? localeController;

  @override
  State<PadelClubApp> createState() => _PadelClubAppState();
}

class _PadelClubAppState extends State<PadelClubApp> {
  late final LocaleController _localeController;

  @override
  void initState() {
    super.initState();
    _localeController = widget.localeController ?? LocaleController();
    _localeController.load();
  }

  @override
  void dispose() {
    if (widget.localeController == null) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: _localeController,
      child: ListenableBuilder(
        listenable: _localeController,
        builder: (context, _) => MaterialApp(
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          title: 'PadelClub',
          theme: PadelTheme.light,
          home: const LoginPage(),
          routes: {
            '/home': widget.homeRouteBuilder ?? (_) => const DashboardPage(),
            '/search': (_) => const SearchScreen(),
            '/reservations': (_) => const _ReservationsRoute(),
            '/products': (_) => const _ProductsRoute(),
            '/courts': (_) => const CourtManagementScreen(),
            '/members': (_) => const UserManagementScreen(),
            '/memberships': (_) => ChangeNotifierProvider(
              create: (_) => MembershipManagementProvider.live(),
              child: const MembershipManagementScreen(),
            ),
            '/orders': (_) => const OrderManagementScreen(),
            '/tournaments': (_) => const _TournamentsRoute(),
            '/notifications': (_) => const NotificationManagementScreen(),
            '/operations/audit': (_) => const _AuditTrailRoute(),
            '/operations/provider-readiness': (_) =>
                const _ProviderReadinessRoute(),
            '/payments': (_) => const PaymentsScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillLogin());
  }

  Future<void> _prefillLogin() async {
    final remembered = await context.read<AuthProvider>().rememberedLogin();
    if (!mounted || remembered == null) return;
    setState(() {
      _emailController.text = remembered.username;
      _passwordController.text = remembered.password;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final usesSavedSession =
        _passwordController.text == AuthProvider.savedSessionPlaceholder;
    final success = usesSavedSession
        ? await auth.restoreRememberedLogin()
        : await auth.login(
            _emailController.text.trim(),
            _passwordController.text,
            rememberMe: _rememberMe,
          );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.tr("Sign in failed")),
          content: Text(context.tr(auth.errorMessage ?? "Please try again.")),
          backgroundColor: PadelColors.danger,
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: _emailController.text.contains('@') ? _emailController.text : '',
    );
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Forgot password")),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr("Email"),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) =>
                FormValidators.email(value, l10n: context.l10n),
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(emailController.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr("Cancel")),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(emailController.text.trim());
              }
            },
            child: Text(context.tr("Send reset link")),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (!mounted || email == null) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.requestPasswordReset(email);
    if (!mounted) return;
    final shouldEnterToken = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.tr(
            success ? "Check your email" : "Password reset unavailable",
          ),
        ),
        content: Text(
          context.tr(
            success
                ? "If an account matches that email, a password reset link will be sent shortly."
                : auth.errorMessage ?? "Please try again.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr("OK")),
          ),
          if (success)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr("Enter reset token")),
            ),
        ],
      ),
    );
    if (!mounted || shouldEnterToken != true) return;

    final resetData = await _showResetPasswordDialog();
    if (!mounted || resetData == null) return;
    final resetSuccess = await auth.resetPassword(
      resetData.token,
      resetData.password,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.tr(
            resetSuccess ? "Password updated." : "Password reset unavailable",
          ),
        ),
        content: Text(
          context.tr(
            resetSuccess
                ? "You can now sign in with your new password."
                : auth.errorMessage ?? "Please try again.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr("OK")),
          ),
        ],
      ),
    );
  }

  Future<({String token, String password})?> _showResetPasswordDialog() async {
    final tokenController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<({String token, String password})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Reset password")),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tokenController,
                  decoration: InputDecoration(
                    labelText: context.tr("Reset token"),
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    label: 'the reset token',
                    l10n: context.l10n,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr("New password"),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    label: 'your password',
                    minLength: 10,
                    l10n: context.l10n,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmationController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr("Confirm password"),
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) => value != passwordController.text
                      ? context.tr("Passwords do not match")
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr("Cancel")),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop((
                  token: tokenController.text.trim(),
                  password: passwordController.text,
                ));
              }
            },
            child: Text(context.tr("Update password")),
          ),
        ],
      ),
    );
    tokenController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD9E4F7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x142E6BD7),
                          blurRadius: 28,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: LanguageSwitcher(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              label: context.tr("PadelClub logo"),
                              image: true,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2E6BD7),
                                      Color(0xFF1F7A63),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.sports_tennis,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.tr("Welcome back"),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              "Sign in to book courts, track matches, and manage your PadelClub activity in one place.",
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: Color(0xFF4E638C),
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: context.tr("Username"),
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return context.tr("Enter your username");
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            onTap: () {
                              if (_passwordController.text ==
                                  AuthProvider.savedSessionPlaceholder) {
                                _passwordController.clear();
                              }
                            },
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: context.tr("Password"),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? context.tr("Show password")
                                    : context.tr("Hide password"),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return context.tr("Enter your password");
                              }
                              if (text.length < 6) {
                                return context.tr("Use at least 6 characters");
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _signIn(),
                          ),
                          const SizedBox(height: 14),
                          Material(
                            type: MaterialType.transparency,
                            child: CheckboxListTile(
                              value: _rememberMe,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: const Color(0xFF1F7A63),
                              title: Text(
                                context.tr(
                                  "Save login information on this device",
                                ),
                                style: TextStyle(color: Color(0xFF4F6059)),
                              ),
                              onChanged: auth.isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : _forgotPassword,
                              child: Text(context.tr("Forgot password?")),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: auth.isLoading ? null : _signIn,
                            child: auth.isLoading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(context.tr("Sign in")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationsRoute extends StatelessWidget {
  const _ReservationsRoute();

  @override
  Widget build(BuildContext context) {
    if (usesDesktopManagement(context)) {
      return context.watch<AuthProvider>().isAdministrator
          ? const ManagementReservationsScreen()
          : _PlaceholderScreen(
              title: context.tr("Management access required"),
              section: AppSection.reservations,
              message: context.tr(
                "Sign in with an administrator account to use the desktop management application.",
              ),
            );
    }
    return const MobileReservationsScreen();
  }
}

class _ProductsRoute extends StatelessWidget {
  const _ProductsRoute();

  @override
  Widget build(BuildContext context) {
    return usesDesktopManagement(context)
        ? const ProductManagementScreen()
        : const ProductListScreen();
  }
}

class _AuditTrailRoute extends StatelessWidget {
  const _AuditTrailRoute();

  @override
  Widget build(BuildContext context) {
    if (!usesDesktopManagement(context)) {
      return _PlaceholderScreen(
        title: context.tr("Audit Trail"),
        section: AppSection.profile,
        message: context.tr(
          "Audit review is available in the desktop management application.",
        ),
      );
    }
    return context.watch<AuthProvider>().isAdministrator
        ? const AuditTrailScreen()
        : _PlaceholderScreen(
            title: context.tr("Management access required"),
            section: AppSection.auditTrail,
            message: context.tr(
              "Sign in with an administrator account to review the audit trail.",
            ),
          );
  }
}

class _ProviderReadinessRoute extends StatelessWidget {
  const _ProviderReadinessRoute();

  @override
  Widget build(BuildContext context) {
    if (!usesDesktopManagement(context)) {
      return _PlaceholderScreen(
        title: context.tr("Provider Readiness"),
        section: AppSection.profile,
        message: context.tr(
          "Provider configuration diagnostics are available in the desktop management application.",
        ),
      );
    }
    return context.watch<AuthProvider>().isAdministrator
        ? const ProviderReadinessScreen()
        : _PlaceholderScreen(
            title: context.tr("Management access required"),
            section: AppSection.auditTrail,
            message: context.tr(
              "Sign in with an administrator account to review provider readiness.",
            ),
          );
  }
}

class _TournamentsRoute extends StatelessWidget {
  const _TournamentsRoute();

  @override
  Widget build(BuildContext context) {
    if (!usesDesktopManagement(context)) {
      return _PlaceholderScreen(
        title: context.tr("Tournament Management"),
        section: AppSection.search,
        message: context.tr(
          "Tournament management is available in the desktop management application.",
        ),
      );
    }
    return context.watch<AuthProvider>().isAdministrator
        ? const TournamentManagementScreen()
        : _PlaceholderScreen(
            title: context.tr("Management access required"),
            section: AppSection.tournaments,
            message: context.tr(
              "Sign in with an administrator account to manage tournaments.",
            ),
          );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.section,
    this.message,
  });

  final String title;
  final AppSection section;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final isAccessMessage = message?.contains('administrator') == true;
    return MasterScreen(
      title: title,
      section: section,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.construction_rounded,
                size: 52,
                color: Color(0xFF2F64E7),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message ??
                    context.tr(
                      "This section is ready for the next management feature.",
                    ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085)),
              ),
              if (isAccessMessage) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (_) => false);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(context.tr("Sign out")),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF5FF), Color(0xFFDCE8FF), Color(0xFFF7FAFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: _BackgroundOrb(size: 180, color: const Color(0x332E6BD7)),
          ),
          Positioned(
            bottom: -70,
            left: -40,
            child: _BackgroundOrb(size: 220, color: const Color(0x222E6BD7)),
          ),
          Positioned(
            top: 96,
            left: 24,
            child: _BackgroundAccent(
              title: 'PadelClub',
              subtitle: context.tr(
                "Fast booking. Clean courts. Better matches.",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _BackgroundAccent extends StatelessWidget {
  const _BackgroundAccent({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: const Color(0xFF2E6BD7),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4E638C)),
        ),
      ],
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6F1), Color(0xFFDCEBE3)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Color(0xFF1F7A63),
                  ),
                  SizedBox(height: 16),
                  Text(
                    context.tr("Welcome to PadelClub"),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF27423A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    context.tr(
                      "Your club dashboard is ready to guide bookings, products, and match activity.",
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5C6B64)),
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
