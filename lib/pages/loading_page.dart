import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/color_constants.dart';
import '../constants/view_page_id.dart';
import '../providers/features/user/auth/dosuka_auth_provider.dart';

/// スプラッシュ/ローディングページ。
/// Firebase初期化後にログイン状態を確認し、適切なページへ遷移する。
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  LoadingPageState createState() => LoadingPageState();
}

class LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // スプラッシュを少し表示する
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final authProvider = context.read<DosukAuthProvider>();
    final bool isLoggedIn = await authProvider.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      context.goNamed(ViewPageId.execution.pageName);
    } else {
      context.goNamed(ViewPageId.login.pageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              '旅、どうすか？',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
