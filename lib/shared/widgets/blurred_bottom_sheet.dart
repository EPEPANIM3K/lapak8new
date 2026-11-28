import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

Future<T?> showBlurredBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? heightFactor,
  double maxWidth = 560,
  bool showDragHandle = false,
  Color backgroundColor = AppColors.surfaceContainerLowest,
}) {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    pageBuilder: (modalContext, animation, _) {
      final media = MediaQuery.of(modalContext);
      final availableHeight =
          (media.size.height - media.padding.top - media.viewInsets.bottom)
              .clamp(0.0, media.size.height)
              .toDouble();
      final sheetHeight = heightFactor == null
          ? null
          : availableHeight * heightFactor;

      void dismiss() => Navigator.of(modalContext, rootNavigator: true).pop();

      return Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                child: Semantics(
                  label: barrierLabel,
                  button: true,
                  onTap: dismiss,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final progress = Curves.easeOutCubic.transform(
                        animation.value,
                      );
                      return BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: 10 * progress,
                          sigmaY: 10 * progress,
                        ),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.4 * progress),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: availableHeight,
                  ),
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: SizedBox(
                      width: double.infinity,
                      height: sheetHeight,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Material(
                          color: backgroundColor,
                          child: SafeArea(
                            top: false,
                            child: showDragHandle
                                ? Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          12,
                                          0,
                                          12,
                                        ),
                                        child: Container(
                                          width: 48,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: AppColors.outlineVariant,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Builder(builder: builder),
                                      ),
                                    ],
                                  )
                                : Builder(builder: builder),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
