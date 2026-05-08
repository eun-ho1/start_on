import 'package:start_on/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders ad focus home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AdFocusApp());
    await tester.pumpAndSettle();

    expect(find.text('오늘의 퀘스트'), findsWidgets);
    expect(find.text('던전'), findsOneWidget);
    expect(find.text('상점'), findsOneWidget);
  });
}
