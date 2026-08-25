import 'package:flutter_test/flutter_test.dart';

import 'package:avafli_example/main.dart';

void main() {
  testWidgets('example app renders the home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // The SDK initializes asynchronously; the loading state renders first.
    expect(find.text('Initializing Avafli SDK...'), findsOneWidget);
  });
}
