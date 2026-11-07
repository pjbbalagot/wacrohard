import 'package:flutter_test/flutter_test.dart';
import 'package:tulai/core/proficiency.dart';

void main() {
  test('proficiency bands use the configured MVP boundaries', () {
    expect(proficiencyForScore(0), 'Beginner');
    expect(proficiencyForScore(39), 'Beginner');
    expect(proficiencyForScore(40), 'Developing');
    expect(proficiencyForScore(59), 'Developing');
    expect(proficiencyForScore(60), 'Intermediate');
    expect(proficiencyForScore(79), 'Intermediate');
    expect(proficiencyForScore(80), 'Proficient');
    expect(proficiencyForScore(100), 'Proficient');
  });
  test('rejects scores outside percentage range', () {
    expect(() => proficiencyForScore(-1), throwsArgumentError);
    expect(() => proficiencyForScore(101), throwsArgumentError);
  });
}
