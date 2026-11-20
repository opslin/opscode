import 'package:bakaloo_flutter_app/core/theme/app_theme.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final storefront = await Storefront.load();
    runApp(ProviderScope(child: GroceryApp(storefront: storefront)));
  } on Object {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Could not load assets/demo/storefront.json.'),
          ),
        ),
      ),
    );
  }
}

class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key, required this.storefront});
  final Storefront storefront;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width.clamp(0.0, 480.0);
    return ColoredBox(
      color: const Color(0xFFF0EDF5),
      child: Center(
        child: SizedBox(
          width: width,
          height: media.size.height,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              builder: (context, child) => MaterialApp(
                title: storefront.brand,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: child,
              ),
              child: HomeScreen(storefront: storefront),
            ),
          ),
        ),
      ),
    );
  }
}
