import 'package:flutter/material.dart';
import '../../constants/color_constants.dart';

/// travel_dosuka共通のScaffold
class DosukScaffold extends StatelessWidget {
  final Widget child;
  final String title;
  final bool centerTitle;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final void Function()? onGoBackPressed;

  const DosukScaffold({
    super.key,
    required this.child,
    required this.title,
    this.centerTitle = false,
    this.appBarActions,
    this.floatingActionButton,
    this.onGoBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: centerTitle,
        automaticallyImplyLeading: false,
        backgroundColor: ColorConstants.themeColor,
        foregroundColor: Colors.white,
        leading: onGoBackPressed == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onGoBackPressed,
              ),
        actions: appBarActions,
      ),
      floatingActionButton: floatingActionButton,
      backgroundColor: ColorConstants.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
