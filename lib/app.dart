import 'package:flutter/material.dart';
import 'core/router.dart';

class SocialSaasApp extends StatelessWidget {
  const SocialSaasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Social SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        fontFamily: 'Cairo', // اختياري — لو عايز خط عربي حلو
      ),
      routerConfig: router,
    );
  }
}
