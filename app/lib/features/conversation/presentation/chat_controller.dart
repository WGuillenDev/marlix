import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/api_providers.dart';
import '../../../shared/application/api_exception.dart';
import '../../account/presentation/session_state.dart';
import '../../safety/domain/help_resource.dart';
import '../../voice/presentation/read_aloud.dart';
import '../application/conversation_gateway.dart';
import '../domain/chat.dart';
import '../domain/usage.dart';

sealed class ChatEntry {
  const ChatEntry(this.id);

  final String id;
}

enum SendStatus { sending, sent, failed }

enum SendFailure { network, timeout, unavailable, tooFast, dailyLimit, sessionEnded, unexpected }

class UserEntry extends ChatEntry {
  const UserEntry(
    super.id, {
    required this.text,
    required this.status,
    this.failure,
    this.retryAfter,
  });

  final String text;
  final SendStatus status;
  final SendFailure? failure;

  final Duration? retryAfter;

  /// Recoverable send errors can retry once the session and quota allow it.
  bool get canRetry =>
      status == SendStatus.failed &&
      failure != SendFailure.dailyLimit &&
      failure != SendFailure.sessionEnded;
}

class MarlixEntry extends ChatEntry {
  MarlixEntry(this.message, {this.tone = MessageTone.neutral}) : super(message.id);

  final ChatMessage message;

  final MessageTone tone;
}

class CrisisEntry extends ChatEntry {
  CrisisEntry(this.message, this.resources) : super(message.id);

  final ChatMessage message;
  final List<HelpResource> resources;
}

enum HistoryStatus { pending, idle, loading, failed }

class ChatState {
  const ChatState({
    this.entries = const [],
    this.usage,
    this.limitResetsAt,
    this.historyStatus = HistoryStatus.pending,
    this.hasOlder = true,
  });

  /// Messages remain oldest first after prepending history.
  final List<ChatEntry> entries;

  final HistoryStatus historyStatus;

  /// Assume an older page exists until the backend indicates otherwise.
  final bool hasOlder;

  /// Usage is unknown until a usage request or reply reports it.
  final Usage? usage;

  final DateTime? limitResetsAt;

  bool get sending =>
      entries.any((entry) => entry is UserEntry && entry.status == SendStatus.sending);

  /// Release the daily limit after the reset, including while the app stays open.
  bool get limitReached {
    final now = DateTime.now();
    if (limitResetsAt case final resetsAt? when now.isBefore(resetsAt)) return true;
    final usage = this.usage;
    return usage != null && usage.remaining == 0 && now.isBefore(usage.resetsAt);
  }

  ChatState copyWith({
    List<ChatEntry>? entries,
    Usage? usage,
    DateTime? limitResetsAt,
    HistoryStatus? historyStatus,
    bool? hasOlder,
  }) => ChatState(
    entries: entries ?? this.entries,
    usage: usage ?? this.usage,
    limitResetsAt: limitResetsAt ?? this.limitResetsAt,
    historyStatus: historyStatus ?? this.historyStatus,
    hasOlder: hasOlder ?? this.hasOlder,
  );
}

class ChatController extends Notifier<ChatState> {
  var _localIds = 0;

  /// Cursor for older history, absent before the first load and at the end.
  String? _olderCursor;

  // Scope chat state to one signed-in account.
  @override
  ChatState build() {
    ref.watch(signedInUserProvider);
    _olderCursor = null;
    return const ChatState();
  }

  ConversationGateway get _api => ref.read(conversationGatewayProvider);

  // Leave the usage indicator hidden when the initial lookup fails.
  Future<void> loadUsage() async {
    try {
      final usage = await _api.usage();
      if (ref.mounted) state = state.copyWith(usage: usage);
    } on UnauthorizedException {
      if (ref.mounted) await _endSession();
    } on ApiException {
      // The next reply can supply the usage count.
    }
  }

  /// History failures are retryable without clearing messages already loaded.
  Future<void> loadHistory() async {
    if (state.historyStatus == HistoryStatus.loading || !state.hasOlder) return;
    state = state.copyWith(historyStatus: HistoryStatus.loading);
    try {
      final page = await _api.history(before: _olderCursor);
      if (!ref.mounted) return;
      _olderCursor = page.nextCursor;
      // De-duplicate messages sent while the history request was in flight.
      final known = {for (final entry in state.entries) entry.id};
      state = state.copyWith(
        entries: [
          for (final message in page.messages)
            if (!known.contains(message.id)) _entryOf(message),
          ...state.entries,
        ],
        historyStatus: HistoryStatus.idle,
        hasOlder: page.nextCursor != null,
      );
    } on UnauthorizedException {
      if (ref.mounted) await _endSession();
    } on ApiException {
      if (ref.mounted) state = state.copyWith(historyStatus: HistoryStatus.failed);
    }
  }

  static ChatEntry _entryOf(ChatMessage message) => switch (message.role) {
    MessageRole.user => UserEntry(message.id, text: message.content, status: SendStatus.sent),
    MessageRole.assistant => MarlixEntry(message),
  };

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending || state.limitReached) return;
    final id = 'local-${_localIds++}';
    state = state.copyWith(
      entries: [
        ...state.entries,
        UserEntry(id, text: message, status: SendStatus.sending),
      ],
    );
    await _deliver(id, message);
  }

  Future<void> retry(String id) async {
    final entry = state.entries.whereType<UserEntry>().where((e) => e.id == id).firstOrNull;
    if (entry == null || !entry.canRetry || state.sending) return;
    _replace(id, UserEntry(id, text: entry.text, status: SendStatus.sending));
    await _deliver(id, entry.text);
  }

  Future<void> _deliver(String id, String text) async {
    StreamController<String>? live;
    try {
      // Voice mode streams sentences so playback can start before the full reply arrives.
      final ChatResponse response;
      if (ref.read(repliesAreSpokenProvider)) {
        response = await _api.sendVoiceMessage(
          text,
          onSentence: (sentence) {
            if (!ref.mounted) return;
            if (live == null) {
              live = StreamController<String>();
              ref.read(liveReplyProvider.notifier).set(live!.stream);
            }
            live!.add(sentence);
          },
        );
      } else {
        response = await _api.sendMessage(text);
      }
      if (!ref.mounted) return;
      final reply = switch (response) {
        CrisisReply(:final reply, :final resources) => CrisisEntry(reply, resources),
        ChatReply(:final reply, :final tone) => MarlixEntry(reply, tone: tone),
      };
      state = state.copyWith(
        entries: [
          for (final entry in state.entries)
            if (entry.id == id) ...[
              UserEntry(id, text: text, status: SendStatus.sent),
              reply,
            ] else
              entry,
        ],
        usage: response.usage,
      );
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      _replace(
        id,
        UserEntry(
          id,
          text: text,
          status: SendStatus.failed,
          failure: _failureOf(error),
          retryAfter: error is RateLimitedException ? error.retryAfter : null,
        ),
      );
      if (error is DailyLimitReachedException) {
        state = state.copyWith(limitResetsAt: error.resetsAt);
      }
      // Supabase already refreshes tokens. A rejected session must return to sign-in.
      if (error is UnauthorizedException) await _endSession();
    } finally {
      unawaited(live?.close());
      if (ref.mounted) ref.read(liveReplyProvider.notifier).set(null);
    }
  }

  Future<void> _endSession() async {
    ref.read(sessionEndedProvider.notifier).set(true);
    await ref.read(authServiceProvider).signOut();
  }

  void _replace(String id, ChatEntry replacement) {
    state = state.copyWith(
      entries: [for (final entry in state.entries) entry.id == id ? replacement : entry],
    );
  }

  static SendFailure _failureOf(ApiException error) => switch (error) {
    NetworkException() => SendFailure.network,
    ApiTimeoutException() => SendFailure.timeout,
    LlmUnavailableException() => SendFailure.unavailable,
    RateLimitedException() => SendFailure.tooFast,
    DailyLimitReachedException() => SendFailure.dailyLimit,
    UnauthorizedException() => SendFailure.sessionEnded,
    _ => SendFailure.unexpected,
  };
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

class LiveReply extends Notifier<Stream<String>?> {
  @override
  Stream<String>? build() => null;

  void set(Stream<String>? sentences) => state = sentences;
}

final liveReplyProvider = NotifierProvider<LiveReply, Stream<String>?>(LiveReply.new);
