import 'package:flutter/material.dart';

import '../onboarding.dart';
import 'profile_labels.dart';

class AccountSettingsPage extends StatefulWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onResetOnboarding;
  final Future<void> Function() onEditProfile;
  final bool showDebugMealDetails;
  final ValueChanged<bool> onDebugMealDetailsChanged;

  const AccountSettingsPage({
    super.key,
    required this.onboardingResult,
    required this.onResetOnboarding,
    required this.onEditProfile,
    required this.showDebugMealDetails,
    required this.onDebugMealDetailsChanged,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late bool _showDebugMealDetails;

  @override
  void initState() {
    super.initState();
    _showDebugMealDetails = widget.showDebugMealDetails;
  }

  OnboardingResult? get onboardingResult => widget.onboardingResult;
  VoidCallback get onResetOnboarding => widget.onResetOnboarding;
  Future<void> Function() get onEditProfile => widget.onEditProfile;

  void _setDebugMealDetails(bool enabled) {
    setState(() => _showDebugMealDetails = enabled);
    widget.onDebugMealDetailsChanged(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final result = onboardingResult;
    final userName = result == null
        ? 'Your profile'
        : '${sexLabel(result.sex)} profile';
    final subtitle = result == null
        ? 'Your nutrition details are stored on this device.'
        : '${goalLabel(result.goalType)} | ${activityLabel(result.activityLevel)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F6),
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Profile settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3558),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8088A2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onEditProfile,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C7AE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFFB06B42),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF29324E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Edit your goal, body data, and daily plan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A91A8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit,
                          color: Color(0xFF2E6AF5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Data'),
              const _SettingsCard(
                child: _SettingsInfoRow(
                  icon: Icons.phone_android_rounded,
                  iconColor: Color(0xFF2E6AF5),
                  title: 'Local-only beta',
                  subtitle:
                      'Your onboarding and meal history stay on this device. Accounts and cloud sync are not available yet.',
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Beta tools'),
              _SettingsCard(
                child: SwitchListTile(
                  key: const Key('debug-meal-details-switch'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text(
                    'Debug meal details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A3353),
                    ),
                  ),
                  subtitle: const Text(
                    'Show technical meal details before editing',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A91A8)),
                  ),
                  value: _showDebugMealDetails,
                  onChanged: _setDebugMealDetails,
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Onboarding'),
              _SettingsCard(
                child: _SettingsActionRow(
                  icon: Icons.restart_alt_rounded,
                  iconColor: const Color(0xFFE5793A),
                  title: 'Restart onboarding',
                  subtitle: 'Recalculate your nutrition plan',
                  onTap: () => _confirmReset(context),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Restarting onboarding keeps your existing meal history on this device.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A91A8),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restart onboarding?'),
        content: const Text(
          'Your meal history will stay on this device, but you will set up your nutrition plan again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      onResetOnboarding();
    }
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String label;

  const _SettingsSectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFFA2A9BD),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE9EBF2)),
    ),
    child: child,
  );
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SettingsInfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsIcon(icon: icon, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A3353),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A91A8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A3353),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A91A8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8690AB)),
        ],
      ),
    ),
  );
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: 16),
  );
}
