import 'package:agrosight/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgroScan launches onboarding', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('AgroScan'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
