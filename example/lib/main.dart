import 'package:flutter/material.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WINR Flutter SDK Example',
      debugShowCheckedModeBanner: false,
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

  Campaign? _campaign;
  StreakState? _streakState;
  bool _claimedToday = false;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    try {
      // Initialize the WINR SDK with configuration
      await WINR.configure(WINROptions(
        apiKey: 'demo-api-key-12345',
        environment: WINREnvironment.production,
        branding: const WINRBranding(
          primaryColor: Color(0xFF6366F1),
          primaryButtonColor: Color(0xFF8B5CF6),
          accentGlowColor: Color(0xFFEC4899),
          backgroundColor: Color(0xFF0F172A),
          cardBackgroundColor: Color(0xFF1E293B),
          cardBorderColor: Color(0xFF334155),
          primaryButtonTextColor: Colors.white,
          secondaryButtonColor: Color(0xFF334155),
          secondaryButtonTextColor: Color(0xFFCBD5E1),
          secondaryTextColor: Color(0xFFCBD5E1),
          mutedTextColor: Color(0xFF64748B),
          inputFieldBackgroundColor: Color(0xFF334155),
          inputFieldBorderColor: Color(0xFF475569),
          inputFieldPlaceholderColor: Color(0xFF94A3B8),
          cornerRadius: 16.0,
        ),
        analyticsAdapter: DemoAnalyticsAdapter(),
        logging: LoggingLevel.debug,
      ));

      // Set demo user information
      WINR.setUser(WINRUser(id: 'demo_user_123'));

      // Load initial data
      await _loadData();

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

  Future<void> _loadData() async {
    // In a real app, this data comes from the WINR backend automatically.
    // For demo purposes, we create mock data to show the UI components.
    _campaign = const Campaign(
      id: 'demo_campaign',
      title: 'Win \$10,000 Cash',
      period: CampaignPeriod.monthly,
      maxDailyBaseEntries: 300,
      doublingEnabled: true,
      streakConfig: StreakConfig(),
      prizeDescription: 'Enter daily for your chance to win big!',
      prizeValue: 10000.0,
    );

    _streakState = const StreakState(
      currentDay: 3,
      totalEntriesEarned: 30,
    );

    _claimedToday = false;
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
              'Initializing WINR SDK...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
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
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
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
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
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
          _buildExampleCards(),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 32),
          _buildDemoData(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WINR Flutter SDK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Example Integration',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
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
              Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SDK initialized successfully!',
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

  Widget _buildExampleCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Examples',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Small card example
        WINRExperienceCard(
          branding: WINRBranding.defaultBranding(),
          campaign: _campaign,
          streakState: _streakState,
          claimedToday: _claimedToday,
          size: WINRCardSize.small,
          onTap: () => _showFullExperience(),
          onQuickClaim: () => _handleQuickClaim(),
        ),

        const SizedBox(height: 16),

        // Medium card example
        WINRExperienceCard(
          branding: WINRBranding.defaultBranding(),
          campaign: _campaign,
          streakState: _streakState,
          claimedToday: _claimedToday,
          size: WINRCardSize.medium,
          onTap: () => _showFullExperience(),
          onQuickClaim: () => _handleQuickClaim(),
        ),

        const SizedBox(height: 16),

        // Large card example
        WINRExperienceCard(
          branding: WINRBranding.defaultBranding(),
          campaign: _campaign,
          streakState: _streakState,
          claimedToday: _claimedToday,
          size: WINRCardSize.large,
          onTap: () => _showFullExperience(),
          onQuickClaim: () => _handleQuickClaim(),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showFullExperience(),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Full Experience'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showHowItWorks(),
            icon: const Icon(Icons.help_outline),
            label: const Text('How It Works'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _resetDemo(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Demo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demo Data',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDataRow('Campaign ID', _campaign?.id ?? 'None'),
              _buildDataRow('Prize Value',
                  '\$${_campaign?.prizeValue?.toStringAsFixed(0) ?? '0'}'),
              _buildDataRow(
                  'Current Streak', '${_streakState?.currentDay ?? 0} days'),
              _buildDataRow(
                  'Total Entries', '${_streakState?.totalEntriesEarned ?? 0}'),
              _buildDataRow('Claimed Today', _claimedToday ? 'Yes' : 'No'),
              _buildDataRow('SDK Version', '1.0.0'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Actions

  Future<void> _showFullExperience() async {
    try {
      final result = await WINR.present(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entries claimed: ${result.total}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadData();
      setState(() {});
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

  void _showHowItWorks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: HowItWorksView(
          branding: WINRBranding.defaultBranding(),
          onClose: () => Navigator.of(context).pop(),
          campaignTitle: _campaign?.title,
          prizeValue: _campaign?.prizeValue,
        ),
      ),
    );
  }

  Future<void> _handleQuickClaim() async {
    if (_claimedToday) return;

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _claimedToday = true;
      _streakState = _streakState?.copyWith(
        currentDay: (_streakState?.currentDay ?? 0) + 1,
        lastClaimedDate: DateTime.now(),
        totalEntriesEarned: (_streakState?.totalEntriesEarned ?? 0) + 10,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily entries claimed! +10 entries'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _resetDemo() {
    setState(() {
      _claimedToday = false;
      _streakState = const StreakState(
        currentDay: 1,
        totalEntriesEarned: 0,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo data reset'),
        backgroundColor: Colors.blue,
      ),
    );
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
