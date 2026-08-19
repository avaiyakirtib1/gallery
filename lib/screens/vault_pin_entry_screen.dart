import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import 'vault_grid_screen.dart';

/// Custom curve for the passcode wrong-entry shake animation
class _ShakeCurve extends Curve {
  @override
  double transform(double t) {
    // Shakes left and right 3 times
    return math.sin(t * math.pi * 3);
  }
}

class VaultPinEntryScreen extends StatefulWidget {
  const VaultPinEntryScreen({super.key});

  @override
  State<VaultPinEntryScreen> createState() => _VaultPinEntryScreenState();
}

class _VaultPinEntryScreenState extends State<VaultPinEntryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _currentInput = '';
  String _firstAttemptPin = '';
  bool _isConfirming = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24.0)
        .chain(CurveTween(curve: _ShakeCurve()))
        .animate(_shakeController);

    final provider = context.read<GalleryProvider>();
    _hasPin = provider.hasVaultPin;
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberTap(int val) {
    if (_currentInput.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput += val.toString();
    });

    if (_currentInput.length == 4) {
      // Delay slightly for visual effect before processing
      Future.delayed(const Duration(milliseconds: 150), _processPin);
    }
  }

  void _onBackspace() {
    if (_currentInput.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
    });
  }

  void _onClear() {
    if (_currentInput.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _currentInput = '';
    });
  }

  Future<void> _processPin() async {
    final provider = context.read<GalleryProvider>();

    if (!_hasPin) {
      // PIN SETUP FLOW
      if (!_isConfirming) {
        _firstAttemptPin = _currentInput;
        setState(() {
          _isConfirming = true;
          _currentInput = '';
        });
      } else {
        if (_currentInput == _firstAttemptPin) {
          // Success, save PIN
          await provider.setVaultPin(_currentInput);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VaultGridScreen()),
            );
          }
        } else {
          // Error mismatch
          _shake();
          setState(() {
            _isConfirming = false;
            _firstAttemptPin = '';
            _currentInput = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PINs do not match. Restarting setup.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // AUTH FLOW
      final isCorrect = await provider.verifyVaultPin(_currentInput);
      if (isCorrect) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VaultGridScreen()),
          );
        }
      } else {
        _shake();
        setState(() {
          _currentInput = '';
        });
      }
    }
  }

  void _shake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
  }

  void _showResetDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Reset Vault?'),
          ],
        ),
        content: const Text(
          'For privacy, offline vaults cannot be restored if the PIN is lost. '
          'Resetting the vault will PERMANENTLY ERASE all items inside it from your storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<GalleryProvider>();
              await provider.resetVault();
              if (mounted) {
                Navigator.pop(context); // Close PIN screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vault reset successfully. All items cleared.'),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset & Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String promptTitle;
    String promptSubtitle;
    if (!_hasPin) {
      promptTitle = _isConfirming ? 'Confirm Vault PIN' : 'Create Vault PIN';
      promptSubtitle = _isConfirming
          ? 'Re-enter your 4-digit PIN to confirm'
          : 'Choose a 4-digit security PIN to protect private files';
    } else {
      promptTitle = 'Vault Locked';
      promptSubtitle = 'Enter your PIN to access your private vault';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),

                      // Lock Icon with premium glowing container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.15),
                              colorScheme.secondary.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _hasPin ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Prompt Text
                      Text(
                        promptTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          promptSubtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Dots indicator (shaking on wrong passcode)
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _currentInput.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? colorScheme.primary : Colors.transparent,
                                border: Border.all(
                                  color: filled ? colorScheme.primary : Colors.white24,
                                  width: 2,
                                ),
                                boxShadow: filled
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : [],
                              ),
                            );
                          }),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Dialpad Pad Grid
                      _buildDialpad(colorScheme, textTheme),

                      // Help actions
                      if (_hasPin)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: TextButton(
                            onPressed: _showResetDialog,
                            child: Text(
                              'Forgot PIN? Reset Vault',
                              style: TextStyle(
                                color: colorScheme.error.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDialpad(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DialButton(digit: 1, onTap: _onNumberTap),
              _DialButton(digit: 2, onTap: _onNumberTap),
              _DialButton(digit: 3, onTap: _onNumberTap),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DialButton(digit: 4, onTap: _onNumberTap),
              _DialButton(digit: 5, onTap: _onNumberTap),
              _DialButton(digit: 6, onTap: _onNumberTap),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DialButton(digit: 7, onTap: _onNumberTap),
              _DialButton(digit: 8, onTap: _onNumberTap),
              _DialButton(digit: 9, onTap: _onNumberTap),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Clear button
              _IconButton(
                icon: Icons.clear_all_rounded,
                onTap: _onClear,
                colorScheme: colorScheme,
              ),
              _DialButton(digit: 0, onTap: _onNumberTap),
              // Backspace button
              _IconButton(
                icon: Icons.backspace_outlined,
                onTap: _onBackspace,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  final int digit;
  final ValueChanged<int> onTap;

  const _DialButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(38),
          onTap: () => onTap(digit),
          child: Center(
            child: Text(
              digit.toString(),
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(38),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
