import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoutidrowApp());
    expect(find.text('ROUTIDROW'), findsOneWidget);
  });
}
