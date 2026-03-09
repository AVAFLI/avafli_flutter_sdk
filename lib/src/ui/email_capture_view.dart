import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Email capture view with age gate (13+) verification.
/// 
/// Provides a form to capture user email and confirm they meet minimum age
/// requirements. Includes validation and compliance with regulations.
class EmailCaptureView extends StatefulWidget {
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// Callback when email is successfully submitted
  final Function(String email, int age) onEmailSubmitted;
  
  /// Callback when user chooses to skip email capture
  final VoidCallback onSkip;
  
  /// Optional URL for official rules
  final String? rulesUrl;
  
  /// Optional pre-filled email
  final String? prefillEmail;

  const EmailCaptureView({
    super.key,
    required this.branding,
    required this.onEmailSubmitted,
    required this.onSkip,
    this.rulesUrl,
    this.prefillEmail,
  });

  @override
  State<EmailCaptureView> createState() => _EmailCaptureViewState();
}

class _EmailCaptureViewState extends State<EmailCaptureView>
    with TickerProviderStateMixin {
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  
  bool _isAgeConfirmed = false;
  bool _isLoading = false;
  String? _emailError;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Pre-fill email if provided
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                _buildTitle(),
                const SizedBox(height: 32),
                _buildEmailField(),
                const SizedBox(height: 24),
                _buildAgeGate(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildSkipButton(),
                const SizedBox(height: 24),
                _buildLegalText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogo() {
    if (widget.branding.logo != null) {
      return SizedBox(
        height: 80,
        child: widget.branding.logo!,
      );
    }
    
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: widget.branding.primaryColor,
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
      ),
      child: Icon(
        Icons.emoji_events,
        size: 40,
        color: widget.branding.primaryButtonTextColor,
      ),
    );
  }
  
  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'WIN PRIZES!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: widget.branding.primaryColor,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Just submit this entry form for your FREE chance to win.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: widget.branding.secondaryTextColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.branding.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.branding.inputFieldBackgroundColor,
            borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
            border: Border.all(
              color: _emailError != null 
                  ? Colors.red.withValues(alpha: 0.6)
                  : widget.branding.inputFieldBorderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: widget.branding.primaryColor,
            ),
            decoration: InputDecoration(
              hintText: 'Ex. johndoe@gmail.com',
              hintStyle: TextStyle(
                fontSize: 16,
                color: widget.branding.inputFieldPlaceholderColor,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: widget.branding.inputFieldPlaceholderColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: _validateEmail,
            onChanged: (value) {
              if (_emailError != null) {
                setState(() {
                  _emailError = null;
                });
              }
            },
            onFieldSubmitted: (_) => _handleSubmit(),
          ),
        ),
        if (_emailError != null) ...[
          const SizedBox(height: 8),
          Text(
            _emailError!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.red.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildAgeGate() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAgeConfirmed = !_isAgeConfirmed;
        });
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _isAgeConfirmed 
                  ? widget.branding.primaryButtonColor 
                  : Colors.transparent,
              border: Border.all(
                color: _isAgeConfirmed 
                    ? widget.branding.primaryButtonColor 
                    : widget.branding.mutedTextColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _isAgeConfirmed
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: widget.branding.primaryButtonTextColor,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'I confirm I am 13 years of age or older',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.branding.secondaryTextColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    final isEnabled = _isAgeConfirmed && 
                     _emailController.text.isNotEmpty && 
                     !_isLoading;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled 
              ? widget.branding.primaryButtonColor 
              : widget.branding.primaryButtonColor.withValues(alpha: 0.4),
          foregroundColor: widget.branding.primaryButtonTextColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.branding.primaryButtonTextColor,
                  ),
                ),
              )
            : Text(
                'ENTER NOW',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
  
  Widget _buildSkipButton() {
    return TextButton(
      onPressed: _isLoading ? null : widget.onSkip,
      child: Text(
        'Skip for now',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: widget.branding.mutedTextColor,
        ),
      ),
    );
  }
  
  Widget _buildLegalText() {
    return Column(
      children: [
        Text(
          'By entering, you agree to the',
          style: TextStyle(
            fontSize: 12,
            color: widget.branding.mutedTextColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.rulesUrl != null) ...[
              GestureDetector(
                onTap: () => _openUrl(widget.rulesUrl!),
                child: Text(
                  'Official Rules',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.branding.primaryButtonColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                ' & ',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.branding.mutedTextColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            GestureDetector(
              onTap: () => _openUrl('https://winfrastructure.us/privacy'),
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.branding.primaryButtonColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // MARK: - Validation & Actions
  
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (!_isAgeConfirmed) {
      setState(() {
        _emailError = 'You must be 13+ to enter';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _emailError = null;
    });
    
    try {
      final email = _emailController.text.trim();
      // Assuming minimum age of 13 for now
      await widget.onEmailSubmitted(email, 13);
    } catch (e) {
      setState(() {
        _emailError = 'Failed to submit email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _openUrl(String url) {
    // In a real implementation, this would use url_launcher
    // For now, just a placeholder
    debugPrint('Opening URL: $url');
  }
}