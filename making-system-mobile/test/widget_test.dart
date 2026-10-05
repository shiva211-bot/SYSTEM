import 'package:flutter_test/flutter_test.dart';
import 'package:making_system_mobile/app.dart';

void main() {
  testWidgets('app renders the four navigation destinations', (tester) async {
    await tester.pumpWidget(const MakingSystemApp());
    await tester.pump();
    expect(find.text('Global'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Ranks'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
