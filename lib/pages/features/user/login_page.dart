import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../constants/color_constants.dart';
import '../../../constants/view_page_id.dart';
import '../../../log.dart';
import '../../../providers/features/user/auth/dosuka_auth_provider.dart';

/// ログインページ。
/// Google認証またはEmail/Passwordによるログインを提供する。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<DosukAuthProvider>();
    final bool success = await authProvider.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.goNamed(ViewPageId.execution.pageName);
    } else {
      _showErrorSnackBar(authProvider.status);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authProvider = context.read<DosukAuthProvider>();
    final bool success = await authProvider.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.goNamed(ViewPageId.execution.pageName);
    } else {
      _showErrorSnackBar(authProvider.status);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showVerificationDialog();
    } on FirebaseAuthException catch (e) {
      logger.w('Sign-up failed: ${e.code}');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: ${e.message ?? e.code}')),
      );
    }
  }

  void _showVerificationDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('メール確認'),
        content: const Text('確認メールを送信しました。メールを確認してからログインしてください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(AuthStatus status) {
    final String message = switch (status) {
      AuthStatus.authenticateCanceled => 'ログインをキャンセルしました',
      AuthStatus.unauthenticated => 'メールアドレスの確認が完了していません',
      _ => 'ログインに失敗しました。再度お試しください',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildEmailForm(),
                  const SizedBox(height: 16),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildGoogleSignInButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(
          Icons.travel_explore,
          size: 64,
          color: ColorConstants.themeColor,
        ),
        SizedBox(height: 16),
        Text(
          '旅、どうすか？',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ColorConstants.themeColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'あなたの旅行体験をもとに次の旅先を提案します',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: ColorConstants.titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (value.length < 6) {
                    return 'パスワードは6文字以上で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: _signInWithEmail,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColorConstants.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ログイン',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _signUpWithEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConstants.themeColor,
                        side: const BorderSide(color: ColorConstants.themeColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '新規登録',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('または', style: TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: const Icon(Icons.login),
        label: const Text(
          'Googleでログイン',
          style: TextStyle(fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.black26),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
