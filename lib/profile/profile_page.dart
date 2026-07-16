import 'dart:math';

import 'package:flutter/material.dart';

import '../onboarding.dart';
import 'account_settings_page.dart';
import 'profile_labels.dart';

class ProfilePage extends StatelessWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onResetOnboarding;
  final Future<void> Function() onEditProfile;
  final bool showDebugMealDetails;
  final ValueChanged<bool> onDebugMealDetailsChanged;

  const ProfilePage({
    super.key,
    this.onboardingResult,
    required this.onResetOnboarding,
    required this.onEditProfile,
    required this.showDebugMealDetails,
    required this.onDebugMealDetailsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final result = onboardingResult;
    final plan = result?.plan;
    final ageValue = result?.age.toString() ?? '--';
    final heightValue = result == null
        ? '--'
        : '${result.heightCm.toStringAsFixed(0)} cm';
    final weightValue = result == null
        ? '--'
        : '${result.weightKg.toStringAsFixed(1)} kg';
    final bmi = result == null
        ? null
        : result.weightKg / pow(result.heightCm / 100, 2);
    final bmiValue = bmi == null ? '--' : bmi.toStringAsFixed(1);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF20243A),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE9E7EE),
                      border: Border.all(
                        color: const Color(0xFFD9DFEE),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 44,
                      color: Color(0xFFFFA377),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: onEditProfile,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2F66F6),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                result == null
                    ? 'Your Profile'
                    : '${sexLabel(result.sex)} Profile',
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222A44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileChip(
                    label: result == null
                        ? 'GOAL'
                        : goalLabel(result.goalType).toUpperCase(),
                  ),
                  _ProfileChip(
                    label: result == null
                        ? 'ACTIVITY'
                        : activityLabel(result.activityLevel).toUpperCase(),
                    bg: const Color(0xFFD7DBE8),
                    textColor: const Color(0xFF4F5978),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProfileMetricCard(
                  title: 'Age',
                  value: ageValue,
                  valueColor: const Color(0xFF2B66F6),
                ),
                _ProfileMetricCard(
                  title: 'Height',
                  value: heightValue,
                  valueColor: const Color(0xFF2B66F6),
                ),
                _ProfileMetricCard(
                  title: 'Weight',
                  value: weightValue,
                  valueColor: const Color(0xFF25A55F),
                ),
                _ProfileMetricCard(
                  title: 'BMI',
                  value: bmiValue,
                  valueColor: const Color(0xFFE5793A),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Daily plan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF283151),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan?.calorieTarget ?? '--'} kcal',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111322),
                    ),
                  ),
                  const Text(
                    'Daily calorie target set during onboarding',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PlanMacroCard(
                          title: 'Protein',
                          value: '${plan?.proteinTargetG ?? '--'}g',
                          valueColor: const Color(0xFF2B66F6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlanMacroCard(
                          title: 'Carbs',
                          value: '${plan?.carbsTargetG ?? '--'}g',
                          valueColor: const Color(0xFFE5793A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlanMacroCard(
                          title: 'Fats',
                          value: '${plan?.fatTargetG ?? '--'}g',
                          valueColor: const Color(0xFF25A55F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountSettingsPage(
                      onboardingResult: result,
                      onResetOnboarding: onResetOnboarding,
                      onEditProfile: onEditProfile,
                      showDebugMealDetails: showDebugMealDetails,
                      onDebugMealDetailsChanged: onDebugMealDetailsChanged,
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.settings, size: 17, color: Color(0xFF606A84)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Profile settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF293252),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 19,
                      color: Color(0xFF606A84),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _ProfileChip({
    required this.label,
    this.bg = const Color(0xFFAEC2F7),
    this.textColor = const Color(0xFF2D4A9E),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: 0.25,
      ),
    ),
  );
}

class _ProfileMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 38) / 2,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE9EBF2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 30,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PlanMacroCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _PlanMacroCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: valueColor,
        ),
      ),
    ],
  );
}
