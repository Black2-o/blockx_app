import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'page_header.dart';

/// The one responsive page shell every screen uses. Centralizes SafeArea, the
/// keyboard-safe scaffold, the max-content-width clamp, and a consistent header
/// so no individual screen can reintroduce the rotate/overflow/scroll bugs
/// (see details/ui-redesign/04-RESPONSIVE-RULES.md).
///
/// Two content modes:
///  - default: [body] is laid out as-is (use when the screen owns its own
///    scrollable, e.g. a pinned search + Expanded list).
///  - [scrollable] = true: [body] is wrapped in a single [SingleChildScrollView]
///    so short screens never overflow in landscape / with large fonts.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    this.body,
    this.slivers,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.scrollable = false,
    this.constrainWidth = true,
    this.padded = true,
    this.showBack = true,
  }) : assert(body == null || slivers == null,
            'Provide either body or slivers, not both.');

  final String? title;
  final List<Widget>? actions;

  /// Box content. Ignored when [slivers] is given.
  final Widget? body;

  /// Sliver content for screens that need a single [CustomScrollView] owner
  /// (e.g. the dashboard Home). When set, the shell owns the scroll.
  final List<Widget>? slivers;

  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  /// Wrap [body] in a scroll view. Leave false when the body owns its own scroll.
  final bool scrollable;

  /// Clamp readable content to [AppSpacing.maxContentWidth] and center it.
  final bool constrainWidth;

  /// Apply the standard screen edge padding.
  final bool padded;

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            if (title != null)
              PageHeader(title: title!, actions: actions, showBack: showBack),
            Expanded(child: _content(context)),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _content(BuildContext context) {
    // Sliver mode: the shell is the single scroll owner.
    if (slivers != null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constrainWidth ? AppSpacing.maxContentWidth : double.infinity,
          ),
          child: CustomScrollView(slivers: slivers!),
        ),
      );
    }

    Widget child = body ?? const SizedBox.shrink();
    if (padded) {
      child = Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPad),
        child: child,
      );
    }
    if (scrollable) {
      child = SingleChildScrollView(child: child);
    }
    if (constrainWidth) {
      child = Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}
