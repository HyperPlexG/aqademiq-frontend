import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/repositories/ada_repository.dart';
import '../../../../shared/widgets/ic.dart';
import 'ada_chrome.dart';

/// FRAMES `ada-history` — chat-history slide-over panel. Lists the user's past
/// Ada conversations; tapping one loads it into the chat, and the compose
/// button starts a fresh conversation. The same chat-history button that
/// opened it closes it, and so does a tap on the dimmed screen beside it.
Future<void> showChatHistory(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Close chat history',
    barrierDismissible: true,
    barrierColor: const Color(0x33140F1C),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => const _ChatHistoryPanel(),
    transitionBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const _weekdays = [
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
];

String _dateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

class _ChatHistoryPanel extends ConsumerWidget {
  const _ChatHistoryPanel();

  /// The dimmed Ada screen left showing on the right.
  static const double _peek = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final convos = ref.watch(adaConversationsProvider);

    void openConversation(String id) {
      unawaited(ref.read(adaChatProvider.notifier).openConversation(id));
      Navigator.of(context).pop();
    }

    void newConversation() {
      ref.read(adaChatProvider.notifier).newConversation();
      Navigator.of(context).pop();
    }

    return Padding(
      padding: const EdgeInsets.only(right: _peek),
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        shadowColor: const Color(0x1F000000),
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 18),
                  child: Row(
                    children: [
                      AdaMenuButton(
                        label: 'Close chat history',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'New chat',
                        excludeSemantics: true,
                        onTap: newConversation,
                        child: GestureDetector(
                          onTap: newConversation,
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              boxShadow: colors.cardShadow,
                            ),
                            child: Ic('edit', size: 21, color: colors.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Chat history',
                  style: AppText.sans(
                    size: 34,
                    weight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: convos.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: colors.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                    error: (_, _) => _Empty(
                      colors: colors,
                      label: "Couldn't load your chats",
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return _Empty(
                          colors: colors,
                          label: 'No chats yet — start one with Ada',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return Semantics(
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => openConversation(c.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dateLabel(c.updatedAt),
                                    style: AppText.sans(
                                      size: 12,
                                      weight: FontWeight.w800,
                                      letterSpacing: AppText.em(0.08, 12),
                                      color: colors.textDim,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c.title,
                                    style: AppText.sans(
                                      size: 17,
                                      weight: FontWeight.w700,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.colors, required this.label});

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
      ),
    );
  }
}
