import 'package:f95seeker/src/f95_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('query sanitizer follows F95Checker behavior', () {
    expect(F95Api.sanitizeQuery("The Summer's Gone!"), 'Summer Gone');
  });

  test('query sanitizer caps searches at 30 characters', () {
    expect(F95Api.sanitizeQuery('a very unusually long searchable game title with extras').length, lessThanOrEqualTo(30));
  });
}
