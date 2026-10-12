import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/onboarding/widgets/penny_avatar.dart';
import 'package:piggybank/shared/widgets/mascot_moment.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool reduced = false}) => tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: MaterialApp(home: Center(child: child)),
        ),
      );

  testWidgets('a welcoming cutout with no clip', (tester) async {
    await pump(tester, const PennyAvatar());
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byType(ClipOval), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    final asset = (provider is ResizeImage ? provider.imageProvider : provider) as AssetImage;
    expect(asset.assetName, MascotMoment.welcoming);
  });

  testWidgets('no looping idle motion: nothing left to animate once settled', (tester) async {
    await pump(tester, const PennyAvatar(entrance: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the entrance fades and springs in once', (tester) async {
    await pump(tester, const PennyAvatar(entrance: true));
    final first = tester.widget<Opacity>(find.byKey(const Key('penny-entrance'))).opacity;
    expect(first, lessThan(0.5));
    await tester.pumpAndSettle();
    // At rest she's the plain cutout again, with no Opacity layer left over.
    expect(find.byKey(const Key('penny-entrance')), findsNothing);

    // A rebuild doesn't replay it.
    await pump(tester, const PennyAvatar(entrance: true, size: 121));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('without the flag, or under reduced motion, she is static', (tester) async {
    await pump(tester, const PennyAvatar());
    expect(find.byKey(const Key('penny-entrance')), findsNothing);
    await pump(tester, const SizedBox());
    await pump(tester, const PennyAvatar(entrance: true), reduced: true);
    expect(find.byKey(const Key('penny-entrance')), findsNothing);
  });
}
