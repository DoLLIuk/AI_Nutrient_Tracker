import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum GoalType { loseWeight, maintain, gainWeight, trackOnly }

enum SexType { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  athlete,
}

enum TargetPace { slow, balanced, fast, leanBulk, moderateBulk, maintain }

enum MacroProfile { balanced, highProtein, lowCarb }

enum HeightUnit { cm, ftIn }

enum WeightUnit { kg, lb }

class NutritionPlan {
  final int calorieTarget;
  final int proteinTargetG;
  final int fatTargetG;
  final int carbsTargetG;

  const NutritionPlan({
    required this.calorieTarget,
    required this.proteinTargetG,
    required this.fatTargetG,
    required this.carbsTargetG,
  });
}

class OnboardingResult {
  final GoalType goalType;
  final SexType sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final TargetPace targetPace;
  final MacroProfile macroProfile;
  final NutritionPlan plan;

  const OnboardingResult({
    required this.goalType,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.targetPace,
    required this.macroProfile,
    required this.plan,
  });
}

class OnboardingFlow extends StatefulWidget {
  final Future<void> Function(OnboardingResult result) onCompleted;
  final ValueChanged<OnboardingDraft>? onDraftChanged;
  final VoidCallback? onStarted;
  final ValueChanged<int>? onStepViewed;
  final OnboardingDraft? initialDraft;
  final bool popOnBackAtEntryStep;

  const OnboardingFlow({
    super.key,
    required this.onCompleted,
    this.onDraftChanged,
    this.onStarted,
    this.onStepViewed,
    this.initialDraft,
    this.popOnBackAtEntryStep = false,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  late final int _entryStep;
  GoalType? _goalType;
  SexType? _sexType;
  ActivityLevel? _activityLevel;
  TargetPace? _targetPace;
  MacroProfile _macroProfile = MacroProfile.balanced;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _feetController = TextEditingController();
  final TextEditingController _inchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  HeightUnit _heightUnit = HeightUnit.cm;
  WeightUnit _weightUnit = WeightUnit.kg;
  String? _basicProfileError;
  bool _isCompleting = false;
  int? _lastReportedStep;

  @override
  void initState() {
    super.initState();
    _restoreDraft(widget.initialDraft);
    _entryStep = _step;
    _ageController.addListener(_notifyDraftChanged);
    _heightController.addListener(_notifyDraftChanged);
    _feetController.addListener(_notifyDraftChanged);
    _inchesController.addListener(_notifyDraftChanged);
    _weightController.addListener(_notifyDraftChanged);
    _notifyDraftChanged();
    _reportCurrentStepIfNeeded();
  }

  void _restoreDraft(OnboardingDraft? draft) {
    if (draft == null) return;
    _step = draft.step;
    _goalType = draft.goalType;
    _sexType = draft.sexType;
    _activityLevel = draft.activityLevel;
    _targetPace = draft.targetPace;
    _macroProfile = draft.macroProfile;
    _heightUnit = draft.heightUnit;
    _weightUnit = draft.weightUnit;
    _ageController.text = draft.ageText;
    _heightController.text = draft.heightText;
    _feetController.text = draft.feetText;
    _inchesController.text = draft.inchesText;
    _weightController.text = draft.weightText;
  }

  OnboardingDraft _buildDraft() {
    return OnboardingDraft(
      step: _step,
      goalType: _goalType,
      sexType: _sexType,
      activityLevel: _activityLevel,
      targetPace: _targetPace,
      macroProfile: _macroProfile,
      heightUnit: _heightUnit,
      weightUnit: _weightUnit,
      ageText: _ageController.text,
      heightText: _heightController.text,
      feetText: _feetController.text,
      inchesText: _inchesController.text,
      weightText: _weightController.text,
    );
  }

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call(_buildDraft());
  }

  void _setStateAndNotify(VoidCallback fn) {
    setState(fn);
    _notifyDraftChanged();
  }

  void _reportCurrentStepIfNeeded() {
    if (_lastReportedStep == _step) return;
    _lastReportedStep = _step;
    widget.onStepViewed?.call(_step);
  }

  void _startOnboarding() {
    widget.onStarted?.call();
    _nextStep();
  }

  void _continueWithSampleProfile() {
    _setStateAndNotify(() {
      _sexType = SexType.female;
      _heightUnit = HeightUnit.cm;
      _weightUnit = WeightUnit.kg;
      _ageController.text = '30';
      _heightController.text = '165';
      _weightController.text = '65';
      _basicProfileError = null;
    });
    if (_validateBasicProfile()) _nextStep();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < 6) {
      _setStateAndNotify(() => _step += 1);
      _reportCurrentStepIfNeeded();
    }
  }

  void _previousStep() {
    if (_step > 0) {
      _setStateAndNotify(() => _step -= 1);
      _reportCurrentStepIfNeeded();
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onCompleted(_buildResult());
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  double? _toDouble(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));
  int? _toInt(String raw) => int.tryParse(raw.trim());

  double? _heightInCm() {
    if (_heightUnit == HeightUnit.cm) return _toDouble(_heightController.text);
    final feet = _toDouble(_feetController.text);
    final inches = _toDouble(_inchesController.text);
    if (feet == null || inches == null) return null;
    return feet * 30.48 + inches * 2.54;
  }

  double? _weightInKg() {
    final value = _toDouble(_weightController.text);
    if (value == null) return null;
    return _weightUnit == WeightUnit.kg ? value : value * 0.45359237;
  }

  _ProfileData? _buildProfileData() {
    final age = _toInt(_ageController.text);
    final heightCm = _heightInCm();
    final weightKg = _weightInKg();
    if (_sexType == null ||
        age == null ||
        heightCm == null ||
        weightKg == null) {
      return null;
    }
    return _ProfileData(
      sex: _sexType!,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
    );
  }

  bool _validateBasicProfile() {
    final data = _buildProfileData();
    if (data == null) {
      setState(
        () =>
            _basicProfileError = 'Please fill in sex, age, height, and weight.',
      );
      return false;
    }
    if (data.age < 13 || data.age > 100) {
      setState(() => _basicProfileError = 'Age must be between 13 and 100.');
      return false;
    }
    if (data.heightCm < 70 || data.heightCm > 220) {
      setState(
        () => _basicProfileError = 'Height must be between 70 and 220 cm.',
      );
      return false;
    }
    if (data.weightKg < 30 || data.weightKg > 250) {
      setState(
        () => _basicProfileError = 'Weight must be between 30 and 250 kg.',
      );
      return false;
    }
    setState(() => _basicProfileError = null);
    return true;
  }

  OnboardingResult _buildResult() {
    final profile = _buildProfileData()!;
    final plan = calculateNutritionPlan(
      goalType: _goalType!,
      sex: profile.sex,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activityLevel: _activityLevel!,
      pace: _targetPace!,
      macroProfile: _macroProfile,
    );
    return OnboardingResult(
      goalType: _goalType!,
      sex: profile.sex,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activityLevel: _activityLevel!,
      targetPace: _targetPace!,
      macroProfile: _macroProfile,
      plan: plan,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: _step == 0,
      appBar: AppBar(
        backgroundColor: _step == 0
            ? Colors.transparent
            : const Color(0xFFF4F5F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('onboarding-back'),
          onPressed: () {
            if (_step == 0) {
              Navigator.of(context).maybePop();
              return;
            }
            if (widget.popOnBackAtEntryStep && _step == _entryStep) {
              Navigator.of(context).maybePop();
              return;
            }
            _previousStep();
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _step == 0 ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (_step) {
          0 => _WelcomeScreen(onContinue: _startOnboarding),
          1 => _StepScaffold(
            key: const ValueKey('goal-step'),
            step: 1,
            title: "What's your goal?",
            subtitle: 'Choose what you want to achieve',
            canContinue: _goalType != null,
            onContinue: _nextStep,
            child: _GoalStep(
              selected: _goalType,
              onSelected: (v) => _setStateAndNotify(() => _goalType = v),
            ),
          ),
          2 => _StepScaffold(
            key: const ValueKey('profile-step'),
            step: 2,
            title: 'Basic profile',
            subtitle: 'Tell us about yourself',
            canContinue: true,
            onContinue: () {
              if (_validateBasicProfile()) _nextStep();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kIsWeb) ...[
                  _SampleProfileCard(onContinue: _continueWithSampleProfile),
                  const SizedBox(height: 22),
                ],
                _BasicProfileStep(
                  sexType: _sexType,
                  ageController: _ageController,
                  heightController: _heightController,
                  feetController: _feetController,
                  inchesController: _inchesController,
                  weightController: _weightController,
                  heightUnit: _heightUnit,
                  weightUnit: _weightUnit,
                  errorText: _basicProfileError,
                  onSexChanged: (v) => _setStateAndNotify(() => _sexType = v),
                  onHeightUnitChanged: (v) =>
                      _setStateAndNotify(() => _heightUnit = v),
                  onWeightUnitChanged: (v) =>
                      _setStateAndNotify(() => _weightUnit = v),
                ),
              ],
            ),
          ),
          3 => _StepScaffold(
            key: const ValueKey('activity-step'),
            step: 3,
            title: 'Activity level',
            subtitle: 'How active are you on a typical day?',
            canContinue: _activityLevel != null,
            onContinue: _nextStep,
            child: _ActivityStep(
              selected: _activityLevel,
              onSelected: (v) => _setStateAndNotify(() => _activityLevel = v),
            ),
          ),
          4 => _StepScaffold(
            key: const ValueKey('pace-step'),
            step: 4,
            title: 'Choose your pace',
            subtitle: _goalType == GoalType.gainWeight
                ? 'How fast do you want to gain weight?'
                : 'How fast do you want to reach your goal?',
            canContinue: _targetPace != null,
            onContinue: _nextStep,
            child: _PaceStep(
              goalType: _goalType,
              selected: _targetPace,
              onSelected: (v) => _setStateAndNotify(() => _targetPace = v),
            ),
          ),
          5 => _StepScaffold(
            key: const ValueKey('macro-step'),
            step: 5,
            title: 'Macro preference',
            subtitle: 'How do you want to split your macros?',
            canContinue: true,
            onContinue: _nextStep,
            child: _MacroStep(
              selected: _macroProfile,
              onSelected: (v) => _setStateAndNotify(() => _macroProfile = v),
              onSkip: _nextStep,
            ),
          ),
          _ => _ResultStep(
            result: _buildResult(),
            onStart: _completeOnboarding,
            isSubmitting: _isCompleting,
            onEdit: () => _setStateAndNotify(() => _step = 5),
          ),
        },
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final bool canContinue;
  final VoidCallback onContinue;

  const _StepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.canContinue,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $step of 6',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF525A6E),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: step / 6,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFD5D8E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4A5568),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: child,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              border: Border(top: BorderSide(color: Color(0xFFDADDE5))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFC4CAD5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: canContinue ? onContinue : null,
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const _WelcomeScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4F63E8), Color(0xFF7B31F0)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: const Center(
                  child: Text('🍎', style: TextStyle(fontSize: 54)),
                ),
              ),
              const SizedBox(height: 38),
              const Text(
                'Track calories from food photos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 31,
                  height: 1.15,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Log meals, track calories and macros, and stay on plan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    minimumSize: const Size.fromHeight(66),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: onContinue,
                  child: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
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

class _GoalStep extends StatelessWidget {
  final GoalType? selected;
  final ValueChanged<GoalType> onSelected;

  const _GoalStep({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChoiceCard(
          title: 'Lose fat',
          subtitle: 'Burn calories and lose weight',
          selected: selected == GoalType.loseWeight,
          icon: Icons.trending_down_rounded,
          iconGradient: const [Color(0xFFFF4040), Color(0xFFFF7A00)],
          onTap: () => onSelected(GoalType.loseWeight),
        ),
        _ChoiceCard(
          title: 'Maintain',
          subtitle: 'Stay at current weight',
          selected: selected == GoalType.maintain,
          icon: Icons.graphic_eq_rounded,
          iconGradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
          onTap: () => onSelected(GoalType.maintain),
        ),
        _ChoiceCard(
          title: 'Gain muscle',
          subtitle: 'Build strength and mass',
          selected: selected == GoalType.gainWeight,
          icon: Icons.trending_up_rounded,
          iconGradient: const [Color(0xFF22C55E), Color(0xFF10B981)],
          onTap: () => onSelected(GoalType.gainWeight),
        ),
        _ChoiceCard(
          title: 'Just track',
          subtitle: 'Monitor nutrition habits',
          selected: selected == GoalType.trackOnly,
          icon: Icons.my_location_rounded,
          iconGradient: const [Color(0xFFA855F7), Color(0xFFEC4899)],
          onTap: () => onSelected(GoalType.trackOnly),
        ),
      ],
    );
  }
}

class _SampleProfileCard extends StatelessWidget {
  final VoidCallback onContinue;

  const _SampleProfileCard({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        border: Border.all(color: const Color(0xFFC9D8FF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Just exploring?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sample details: female · 30 years · 165 cm · 65 kg',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('use-sample-profile'),
              onPressed: onContinue,
              child: const Text('Continue with sample profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicProfileStep extends StatelessWidget {
  final SexType? sexType;
  final HeightUnit heightUnit;
  final WeightUnit weightUnit;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController feetController;
  final TextEditingController inchesController;
  final TextEditingController weightController;
  final String? errorText;
  final ValueChanged<SexType> onSexChanged;
  final ValueChanged<HeightUnit> onHeightUnitChanged;
  final ValueChanged<WeightUnit> onWeightUnitChanged;

  const _BasicProfileStep({
    required this.sexType,
    required this.heightUnit,
    required this.weightUnit,
    required this.ageController,
    required this.heightController,
    required this.feetController,
    required this.inchesController,
    required this.weightController,
    required this.errorText,
    required this.onSexChanged,
    required this.onHeightUnitChanged,
    required this.onWeightUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sex',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChipButton(
                label: 'Male',
                selected: sexType == SexType.male,
                onTap: () => onSexChanged(SexType.male),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChipButton(
                label: 'Female',
                selected: sexType == SexType.female,
                onTap: () => onSexChanged(SexType.female),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LabeledInput(controller: ageController, label: 'Age', hint: 'e.g. 24'),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Height',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _UnitToggle<HeightUnit>(
              values: const [HeightUnit.cm, HeightUnit.ftIn],
              selected: heightUnit,
              labelBuilder: (v) => v == HeightUnit.cm ? 'cm' : 'ft+in',
              onChanged: onHeightUnitChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (heightUnit == HeightUnit.cm)
          _LabeledInput(
            controller: heightController,
            label: 'Height, cm',
            hint: 'e.g. 178',
          )
        else
          Row(
            children: [
              Expanded(
                child: _LabeledInput(
                  controller: feetController,
                  label: 'Feet',
                  hint: 'e.g. 5',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledInput(
                  controller: inchesController,
                  label: 'Inches',
                  hint: 'e.g. 10',
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Weight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _UnitToggle<WeightUnit>(
              values: const [WeightUnit.kg, WeightUnit.lb],
              selected: weightUnit,
              labelBuilder: (v) => v == WeightUnit.kg ? 'kg' : 'lb',
              onChanged: onWeightUnitChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LabeledInput(
          controller: weightController,
          label: 'Weight, ${weightUnit == WeightUnit.kg ? 'kg' : 'lb'}',
          hint: weightUnit == WeightUnit.kg ? 'e.g. 82' : 'e.g. 181',
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class _ActivityStep extends StatelessWidget {
  final ActivityLevel? selected;
  final ValueChanged<ActivityLevel> onSelected;

  const _ActivityStep({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChoiceCard(
          title: 'Sedentary',
          subtitle: 'Mostly sitting, little exercise',
          selected: selected == ActivityLevel.sedentary,
          icon: Icons.chair_outlined,
          iconGradient: const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
          onTap: () => onSelected(ActivityLevel.sedentary),
        ),
        _ChoiceCard(
          title: 'Lightly active',
          subtitle: 'Light workouts 1-2 times/week',
          selected: selected == ActivityLevel.lightlyActive,
          icon: Icons.person_outline_rounded,
          iconGradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
          onTap: () => onSelected(ActivityLevel.lightlyActive),
        ),
        _ChoiceCard(
          title: 'Moderately active',
          subtitle: 'Moderate activity (3-5 workouts/week)',
          selected: selected == ActivityLevel.moderatelyActive,
          icon: Icons.fitness_center_rounded,
          iconGradient: const [Color(0xFF22C55E), Color(0xFF10B981)],
          onTap: () => onSelected(ActivityLevel.moderatelyActive),
        ),
        _ChoiceCard(
          title: 'Very active',
          subtitle: 'High activity (6-7 workouts/week)',
          selected: selected == ActivityLevel.veryActive,
          icon: Icons.local_fire_department_outlined,
          iconGradient: const [Color(0xFFF97316), Color(0xFFEF4444)],
          onTap: () => onSelected(ActivityLevel.veryActive),
        ),
      ],
    );
  }
}

class _PaceStep extends StatelessWidget {
  final GoalType? goalType;
  final TargetPace? selected;
  final ValueChanged<TargetPace> onSelected;

  const _PaceStep({
    required this.goalType,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (goalType == GoalType.maintain || goalType == GoalType.trackOnly) {
      return _ChoiceCard(
        title: 'Maintain calories',
        subtitle: 'No deficit or surplus',
        selected: selected == TargetPace.maintain,
        icon: Icons.horizontal_rule_rounded,
        iconGradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
        onTap: () => onSelected(TargetPace.maintain),
        badge: 'Recommended',
      );
    }

    if (goalType == GoalType.gainWeight) {
      return Column(
        children: [
          _ChoiceCard(
            title: 'Lean bulk',
            subtitle: 'Controlled gain, +250 kcal',
            selected: selected == TargetPace.leanBulk,
            icon: Icons.trending_up_rounded,
            iconGradient: const [Color(0xFF22C55E), Color(0xFF059669)],
            onTap: () => onSelected(TargetPace.leanBulk),
            footnote: '~0.3 lb/week',
          ),
          _ChoiceCard(
            title: 'Moderate bulk',
            subtitle: 'Faster gain, +350 kcal',
            selected: selected == TargetPace.moderateBulk,
            icon: Icons.flash_on_rounded,
            iconGradient: const [Color(0xFFF97316), Color(0xFFEF4444)],
            onTap: () => onSelected(TargetPace.moderateBulk),
            footnote: '~0.6 lb/week',
          ),
        ],
      );
    }

    return Column(
      children: [
        _ChoiceCard(
          title: 'Slow',
          subtitle: 'Easier to sustain, -300 kcal',
          selected: selected == TargetPace.slow,
          icon: Icons.adjust_rounded,
          iconGradient: const [Color(0xFF22C55E), Color(0xFF06B6D4)],
          onTap: () => onSelected(TargetPace.slow),
          footnote: '~0.5 lb/week',
        ),
        _ChoiceCard(
          title: 'Balanced',
          subtitle: 'Steady progress, -400 kcal',
          selected: selected == TargetPace.balanced,
          icon: Icons.trending_up_rounded,
          iconGradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
          onTap: () => onSelected(TargetPace.balanced),
          badge: 'Recommended',
          footnote: '~1 lb/week',
        ),
        _ChoiceCard(
          title: 'Faster',
          subtitle: 'More aggressive, -500 kcal',
          selected: selected == TargetPace.fast,
          icon: Icons.bolt_rounded,
          iconGradient: const [Color(0xFFF97316), Color(0xFFEF4444)],
          onTap: () => onSelected(TargetPace.fast),
          footnote: '~1.5 lb/week',
        ),
      ],
    );
  }
}

class _MacroStep extends StatelessWidget {
  final MacroProfile selected;
  final ValueChanged<MacroProfile> onSelected;
  final VoidCallback onSkip;

  const _MacroStep({
    required this.selected,
    required this.onSelected,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChoiceCard(
          title: 'Balanced',
          subtitle: 'Balanced macro targets',
          selected: selected == MacroProfile.balanced,
          icon: Icons.balance_rounded,
          iconGradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
          onTap: () => onSelected(MacroProfile.balanced),
          badge: 'Recommended',
          footnote: 'Protein 1.6-1.8 g/kg, Fat 0.8 g/kg',
        ),
        _ChoiceCard(
          title: 'High protein',
          subtitle: 'Higher protein target',
          selected: selected == MacroProfile.highProtein,
          icon: Icons.set_meal_outlined,
          iconGradient: const [Color(0xFFFB7185), Color(0xFFEF4444)],
          onTap: () => onSelected(MacroProfile.highProtein),
          footnote: 'Protein up to 2.0 g/kg while cutting',
        ),
        _ChoiceCard(
          title: 'Low carb',
          subtitle: 'Lower carbs, higher fats',
          selected: selected == MacroProfile.lowCarb,
          icon: Icons.grain_outlined,
          iconGradient: const [Color(0xFF22C55E), Color(0xFF10B981)],
          onTap: () => onSelected(MacroProfile.lowCarb),
          footnote: 'Fat priority with carbs from remaining calories',
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onSkip, child: const Text("I'll edit later")),
      ],
    );
  }
}

class _ResultStep extends StatelessWidget {
  final OnboardingResult result;
  final Future<void> Function() onStart;
  final bool isSubmitting;
  final VoidCallback onEdit;

  const _ResultStep({
    required this.result,
    required this.onStart,
    required this.isSubmitting,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 6 of 6',
              style: TextStyle(fontSize: 16, color: Color(0xFF525A6E)),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(
                value: 1,
                minHeight: 5,
                backgroundColor: Color(0xFFD5D8E0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your plan is ready',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Based on your goal and activity level',
              style: TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDCE1EB)),
              ),
              child: Column(
                children: [
                  _ResultRow(
                    label: 'Daily calories',
                    value: '${result.plan.calorieTarget} kcal',
                  ),
                  _ResultRow(
                    label: 'Protein',
                    value: '${result.plan.proteinTargetG} g',
                  ),
                  _ResultRow(
                    label: 'Fat',
                    value: '${result.plan.fatTargetG} g',
                  ),
                  _ResultRow(
                    label: 'Carbs',
                    value: '${result.plan.carbsTargetG} g',
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: isSubmitting ? null : () => onStart(),
                child: const Text(
                  'Start tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  foregroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isSubmitting ? null : onEdit,
                child: const Text('Edit targets'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final List<Color> iconGradient;
  final VoidCallback onTap;
  final String? badge;
  final String? footnote;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.iconGradient,
    required this.onTap,
    this.badge,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF4FF) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFD6DBE5),
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: iconGradient),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (footnote != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        footnote!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const CircleAvatar(
                  radius: 13,
                  backgroundColor: Color(0xFF2563EB),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFD6DBE5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _LabeledInput({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6DBE5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6DBE5)),
        ),
      ),
    );
  }
}

class _UnitToggle<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  const _UnitToggle({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6DBE5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: values
            .map(
              (value) => GestureDetector(
                onTap: () => onChanged(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: value == selected
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labelBuilder(value),
                    style: TextStyle(
                      color: value == selected
                          ? Colors.white
                          : const Color(0xFF334155),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProfileData {
  final SexType sex;
  final int age;
  final double heightCm;
  final double weightKg;

  const _ProfileData({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });
}

NutritionPlan calculateNutritionPlan({
  required GoalType goalType,
  required SexType sex,
  required int age,
  required double heightCm,
  required double weightKg,
  required ActivityLevel activityLevel,
  required TargetPace pace,
  required MacroProfile macroProfile,
}) {
  final bmr =
      (10 * weightKg) +
      (6.25 * heightCm) -
      (5 * age) +
      (sex == SexType.male ? 5 : -161);
  final tdee = bmr * _activityMultiplier(activityLevel);
  final calorieTarget = _targetCalories(
    tdee: tdee,
    goalType: goalType,
    pace: pace,
  );

  final baseProteinPerKg = switch (goalType) {
    GoalType.loseWeight => 2.0,
    GoalType.maintain || GoalType.trackOnly => 1.6,
    GoalType.gainWeight => 1.8,
  };

  final proteinDelta = switch (macroProfile) {
    MacroProfile.balanced => 0.0,
    MacroProfile.highProtein => 0.2,
    MacroProfile.lowCarb => 0.0,
  };
  final fatDelta = switch (macroProfile) {
    MacroProfile.balanced => 0.0,
    MacroProfile.highProtein => 0.0,
    MacroProfile.lowCarb => 0.15,
  };

  final proteinG = (baseProteinPerKg + proteinDelta) * weightKg;
  final fatG = (0.8 + fatDelta) * weightKg;
  final carbsG = max(0.0, (calorieTarget - (proteinG * 4) - (fatG * 9)) / 4);
  return NutritionPlan(
    calorieTarget: calorieTarget.round(),
    proteinTargetG: proteinG.round(),
    fatTargetG: fatG.round(),
    carbsTargetG: carbsG.round(),
  );
}

double _activityMultiplier(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 1.2;
    case ActivityLevel.lightlyActive:
      return 1.375;
    case ActivityLevel.moderatelyActive:
      return 1.55;
    case ActivityLevel.veryActive:
      return 1.725;
    case ActivityLevel.athlete:
      return 1.725;
  }
}

double _targetCalories({
  required double tdee,
  required GoalType goalType,
  required TargetPace pace,
}) {
  switch (goalType) {
    case GoalType.maintain:
    case GoalType.trackOnly:
      return tdee;
    case GoalType.loseWeight:
      return tdee + _calorieAdjustment(goalType, pace);
    case GoalType.gainWeight:
      return tdee + _calorieAdjustment(goalType, pace);
  }
}

int _calorieAdjustment(GoalType goal, TargetPace pace) {
  if (goal == GoalType.loseWeight) {
    switch (pace) {
      case TargetPace.slow:
        return -300;
      case TargetPace.balanced:
        return -400;
      case TargetPace.fast:
        return -500;
      default:
        return -400;
    }
  }

  if (goal == GoalType.gainWeight) {
    switch (pace) {
      case TargetPace.leanBulk:
        return 250;
      case TargetPace.moderateBulk:
        return 350;
      default:
        return 300;
    }
  }

  return 0;
}

class OnboardingDraft {
  final int step;
  final GoalType? goalType;
  final SexType? sexType;
  final ActivityLevel? activityLevel;
  final TargetPace? targetPace;
  final MacroProfile macroProfile;
  final HeightUnit heightUnit;
  final WeightUnit weightUnit;
  final String ageText;
  final String heightText;
  final String feetText;
  final String inchesText;
  final String weightText;

  const OnboardingDraft({
    required this.step,
    required this.goalType,
    required this.sexType,
    required this.activityLevel,
    required this.targetPace,
    required this.macroProfile,
    required this.heightUnit,
    required this.weightUnit,
    required this.ageText,
    required this.heightText,
    required this.feetText,
    required this.inchesText,
    required this.weightText,
  });

  Map<String, dynamic> toJson() => {
    'step': step,
    'goalType': goalType?.name,
    'sexType': sexType?.name,
    'activityLevel': activityLevel?.name,
    'targetPace': targetPace?.name,
    'macroProfile': macroProfile.name,
    'heightUnit': heightUnit.name,
    'weightUnit': weightUnit.name,
    'ageText': ageText,
    'heightText': heightText,
    'feetText': feetText,
    'inchesText': inchesText,
    'weightText': weightText,
  };

  static OnboardingDraft? fromJson(Map<String, dynamic> json) {
    return OnboardingDraft(
      step: ((json['step'] as num?) ?? 0).toInt().clamp(0, 6),
      goalType: _enumByName(GoalType.values, json['goalType'] as String?),
      sexType: _enumByName(SexType.values, json['sexType'] as String?),
      activityLevel: _enumByName(
        ActivityLevel.values,
        json['activityLevel'] as String?,
      ),
      targetPace: _enumByName(TargetPace.values, json['targetPace'] as String?),
      macroProfile:
          _enumByName(MacroProfile.values, json['macroProfile'] as String?) ??
          MacroProfile.balanced,
      heightUnit:
          _enumByName(HeightUnit.values, json['heightUnit'] as String?) ??
          HeightUnit.cm,
      weightUnit:
          _enumByName(WeightUnit.values, json['weightUnit'] as String?) ??
          WeightUnit.kg,
      ageText: (json['ageText'] as String?) ?? '',
      heightText: (json['heightText'] as String?) ?? '',
      feetText: (json['feetText'] as String?) ?? '',
      inchesText: (json['inchesText'] as String?) ?? '',
      weightText: (json['weightText'] as String?) ?? '',
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
