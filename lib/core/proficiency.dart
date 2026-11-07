/// Configurable MVP estimates; not accredited examination thresholds.
String proficiencyForScore(int score) {
  if (score < 0 || score > 100) throw ArgumentError.value(score, 'score', 'Must be between 0 and 100.');
  if (score < 40) return 'Beginner';
  if (score < 60) return 'Developing';
  if (score < 80) return 'Intermediate';
  return 'Proficient';
}
