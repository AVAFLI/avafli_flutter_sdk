import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

/// Must match the bundleId passed to Avafli.configure — the SDK namespaces its
/// auto-present bookkeeping by bundle id.
const String kBundleId = 'com.example.myapp';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Avafli Flutter SDK Example',
      debugShowCheckedModeBanner: false,
      // REQUIRED for the V2 auto-open flow: the SDK presents the experience
      // through this navigator on the first app-open of the day.
      navigatorKey: Avafli.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    try {
      // 1. Configure the Avafli SDK. The experience presents itself: on the
      //    first app-open of each day the V2 drawer auto-opens — provided
      //    Avafli.navigatorKey is attached above. There is no manual launch API.
      await Avafli.configure(AvafliConfiguration(
        apiKey:
            'winr_live_50b1b3b801a843d5e1f99593fcad4d14', // demo key for this example app
        bundleId: kBundleId,
        environment: AvafliEnvironment.production,
        user: const AvafliUser(
          id: 'user_123',
          firstName: 'Jane',
          lastName: 'Doe',
        ),
        options: AvafliOptions(
          logging: LoggingLevel.debug,
          analyticsAdapter: DemoAnalyticsAdapter(),
        ),
      ));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing Avafli SDK...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize SDK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initializeSDK();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '© 2026 AVAFLI • All rights reserved.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avafli wordmark (the brand ships no PNG lockup yet — the site logo
        // is SVG-only, which Image.asset can't render).
        const Text(
          'AVAFLI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.emoji_events, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avafli Flutter SDK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'V2 Example Integration',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SDK configured — the experience auto-opens once per day.',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // DEMO ONLY: clears the SDK's once-per-day auto-present mark and the
        // unregistered impression counter so the team can re-test the V2
        // auto-open flow without waiting for tomorrow. Kill + relaunch the
        // app after tapping — the drawer will auto-present again.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _resetDemoState(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset demo state (auto-open again)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _optOut(),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Erase My Data (GDPR)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Actions

  Future<void> _resetDemoState() async {
    HapticFeedback.mediumImpact();
    // The SDK namespaces its auto-present bookkeeping by bundle id.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('winr_last_auto_present_$kBundleId');
    await prefs.remove('winr_unregistered_impressions_$kBundleId');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Demo state reset — kill and relaunch the app to see auto-open again'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _optOut() async {
    HapticFeedback.mediumImpact();
    try {
      await Avafli.optOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data erased and experience silenced'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Demo analytics adapter that logs events to the console.
class DemoAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    debugPrint('📊 Analytics Event: $eventName');
    if (parameters != null) {
      debugPrint('   Properties: $parameters');
    }
  }

  @override
  void identify(String userId) {
    debugPrint('📊 Analytics Identify: $userId');
  }

  @override
  void setUserProperty(String name, String value) {
    debugPrint('📊 Analytics Property: $name = $value');
  }
}
