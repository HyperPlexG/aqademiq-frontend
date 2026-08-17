import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/repositories/ada_repository.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../../../shared/widgets/empty_state.dart';

/// FRAMES `ada-history` — chat-history slide-over panel. Lists the user's past
/// Ada conversations; tapping one loads it into the chat, and the compose icon
/// starts a fresh conversation.
Future<void> showChatHistory(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Chat history',
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

    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.86,
        child: Material(
          color: colors.surface,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              boxShadow: colors.cardShadow,
                            ),
                            child: Icon(Icons.close, size: 15, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Chat history',
                        style: AppText.sans(
                          size: 26,
                          weight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: colors.text,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: newConversation,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            boxShadow: colors.cardShadow,
                          ),
                          child: Icon(Icons.edit_note, size: 17, color: colors.text),
                        ),
                      ),
                    ],
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
                          return Center(
                            child: SingleChildScrollView(
                              child: EmptyState.compact(
                                title: 'Uhh... no chats yet',
                                subtitle: 'Our conversations land here.',
                                expr: AdaExpr.smile,
                                cheeks: true,
                                ctaLabel: 'Start a chat',
                                ctaIcon: Icons.edit_note,
                                onCta: newConversation,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (_, i) {
                            final c = list[i];
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => openConversation(c.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dateLabel(c.updatedAt),
                                    style: AppText.sans(
                                      size: 9,
                                      weight: FontWeight.w800,
                                      letterSpacing: AppText.em(0.08, 9),
                                      color: colors.textDim,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c.title,
                                    style: AppText.sans(
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
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
        style: AppText.sans(size: 12.5, color: colors.textMed),
      ),
    );
  }
}
