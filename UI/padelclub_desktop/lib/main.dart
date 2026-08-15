import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/dashboard_page.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'package:padelclub_desktop/features/courts/presentation/screens/court_management_screen.dart';
import 'package:padelclub_desktop/features/notifications/presentation/screens/notification_management_screen.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_provider.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/orders/presentation/screens/order_management_screen.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/screens/product_management_screen.dart';
import 'package:padelclub_desktop/features/profile/presentation/screens/profile_screen.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/features/reservations/presentation/screens/reservation_screens.dart';
import 'package:padelclub_desktop/features/reviews/presentation/providers/club_review_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/screens/product_list_screen.dart';
import 'package:padelclub_desktop/features/search/presentation/screens/search_screen.dart';
import 'package:padelclub_desktop/features/search/presentation/providers/discovery_provider.dart';
import 'package:padelclub_desktop/features/tournament/presentation/providers/tournament_provider.dart';
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
  const PadelClubBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = AuthProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ReservationProvider>(
          create: (_) => ReservationProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ChangeNotifierProvider<CourtProvider>(create: (_) => CourtProvider()),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
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
        ChangeNotifierProvider<DiscoveryProvider>(
          create: (_) => DiscoveryProvider(),
        ),
      ],
      child: const PadelClubApp(),
    );
  }
}

class PadelClubApp extends StatelessWidget {
  const PadelClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PadelClub',
      theme: PadelTheme.light,
      home: const LoginPage(),
      routes: {
        '/home': (_) => const DashboardPage(),
        '/search': (_) => const SearchScreen(),
        '/reservations': (_) => const _ReservationsRoute(),
        '/products': (_) => const _ProductsRoute(),
        '/courts': (_) => const CourtManagementScreen(),
        '/members': (_) => const UserManagementScreen(),
        '/orders': (_) => const OrderManagementScreen(),
        '/notifications': (_) => const NotificationManagementScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
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
          title: const Text('Sign in failed'),
          content: Text(auth.errorMessage ?? 'Please try again.'),
        ),
      );
    }
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              label: 'PadelClub logo',
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
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to book courts, track matches, and manage your PadelClub activity in one place.',
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
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Enter your username';
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
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
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
                                return 'Enter your password';
                              }
                              if (text.length < 6) {
                                return 'Use at least 6 characters';
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
                              title: const Text(
                                'Save login information on this device',
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
                                : const Text('Sign in'),
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
          : const _PlaceholderScreen(
              title: 'Management access required',
              section: AppSection.reservations,
              message:
                  'Sign in with an administrator account to use the desktop management application.',
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
                    'This section is ready for the next management feature.',
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
                  label: const Text('Sign out'),
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
          const Positioned(
            top: 96,
            left: 24,
            child: _BackgroundAccent(
              title: 'PadelClub',
              subtitle: 'Fast booking. Clean courts. Better matches.',
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
                children: const [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Color(0xFF1F7A63),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Welcome to PadelClub',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF27423A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your club dashboard is ready to guide bookings, products, and match activity.',
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
