import 'package:f95seeker/src/f95_api.dart';
import 'package:f95seeker/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('query sanitizer follows F95Checker behavior', () {
    expect(F95Api.sanitizeQuery("The Summer's Gone!"), 'Summer Gone');
  });

  test('query sanitizer caps searches at 30 characters', () {
    expect(
        F95Api.sanitizeQuery(
                'a very unusually long searchable game title with extras')
            .length,
        lessThanOrEqualTo(30));
  });

  test('identical searches use the local response cache', () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    final api = F95Api(client: MockClient((_) async {
      requests++;
      return http.Response(
          '{"msg":{"data":[{"thread_id":42,"title":"Cached game","creator":"Dev"}]}}',
          200);
    }));

    final first = await api.search(
        query: 'cached game',
        category: SearchCategory.games,
        field: SearchField.title);
    final second = await api.search(
        query: 'cached game',
        category: SearchCategory.games,
        field: SearchField.title);

    expect(first.single.id, 42);
    expect(second.single.id, 42);
    expect(requests, 1);
  });
}
