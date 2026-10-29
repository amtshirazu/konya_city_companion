import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class KonyaCityCompanionApp extends StatelessWidget {
  const KonyaCityCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Konya City Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
