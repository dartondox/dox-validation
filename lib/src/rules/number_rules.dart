import 'dart:math' as math;

import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';
import 'built_in_rule.dart';

/// Number must be at least [min].
class MinRule<N extends num> extends BuiltInRule<N> {
  MinRule(this.min, {super.message})
    : super(
        IssueCodes.min,
        DefaultMessages.min,
        params: <String, Object?>{'min': min},
        json: <String, dynamic>{'minimum': min},
      );

  final num min;

  @override
  bool check(N value, RuleContext context) {
    return value >= min;
  }
}

/// Number may be at most [max].
class MaxRule<N extends num> extends BuiltInRule<N> {
  MaxRule(this.max, {super.message})
    : super(
        IssueCodes.max,
        DefaultMessages.max,
        params: <String, Object?>{'max': max},
        json: <String, dynamic>{'maximum': max},
      );

  final num max;

  @override
  bool check(N value, RuleContext context) {
    return value <= max;
  }
}

/// Number must be greater than [min].
class GreaterThanRule<N extends num> extends BuiltInRule<N> {
  GreaterThanRule(this.min, {super.message})
    : super(
        IssueCodes.greaterThan,
        DefaultMessages.greaterThan,
        params: <String, Object?>{'min': min},
        json: <String, dynamic>{'exclusiveMinimum': min},
      );

  final num min;

  @override
  bool check(N value, RuleContext context) {
    return value > min;
  }
}

/// Number must be less than [max].
class LessThanRule<N extends num> extends BuiltInRule<N> {
  LessThanRule(this.max, {super.message})
    : super(
        IssueCodes.lessThan,
        DefaultMessages.lessThan,
        params: <String, Object?>{'max': max},
        json: <String, dynamic>{'exclusiveMaximum': max},
      );

  final num max;

  @override
  bool check(N value, RuleContext context) {
    return value < max;
  }
}

/// Number must be a multiple of [factor].
class MultipleOfRule<N extends num> extends BuiltInRule<N> {
  MultipleOfRule(this.factor, {super.message})
    : super(
        IssueCodes.multipleOf,
        DefaultMessages.multipleOf,
        params: <String, Object?>{'factor': factor},
        json: <String, dynamic>{'multipleOf': factor},
      );

  final num factor;

  @override
  bool check(N value, RuleContext context) {
    if (factor == 0) return false;
    if (value is int && factor is int) return value % factor == 0;
    // A whole factor has no binary error, so `%` is exact (also for doubles).
    if (factor == factor.truncateToDouble()) {
      return value.isFinite && value % factor == 0;
    }
    // Fraction factor: 0.3 / 0.1 is 2.9999999999999996, so allow a tiny error.
    // Above 2^53 a double cannot show a fraction, so we cannot prove it and
    // we reject it.
    double quotient = value / factor;
    if (!quotient.isFinite || quotient.abs() > 9007199254740992) return false;
    double error = (value - quotient.roundToDouble() * factor).abs();
    // At least 4e-16 of the value (a few machine epsilons, for one number).
    // Sums of many prices add more error, so allow up to 1e-12 of the value,
    // but never more than a millionth of the factor.
    double floor = value.abs() * 4e-16;
    double cap = math.min(value.abs() * 1e-12, factor.abs() * 1e-6);
    return error <= math.max(floor, cap);
  }
}

/// Number must be from [min] to [max].
class BetweenRule<N extends num> extends BuiltInRule<N> {
  BetweenRule(this.min, this.max, {super.message})
    : super(
        IssueCodes.between,
        DefaultMessages.between,
        params: <String, Object?>{'min': min, 'max': max},
        json: <String, dynamic>{'minimum': min, 'maximum': max},
      );

  final num min;
  final num max;

  @override
  bool check(N value, RuleContext context) {
    return value >= min && value <= max;
  }
}
