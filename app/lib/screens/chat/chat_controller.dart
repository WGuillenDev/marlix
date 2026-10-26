import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat.dart';
import '../../models/help_resource.dart';
import '../../models/usage.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/marlix_api.dart';
import '../../services/read_aloud.dart';

/// One row of the chat.
sealed class ChatEntry {
  const ChatEntry(this.id);

  final String id;
}

enum SendStatus { sending, sent, failed }

/// Why a message was not sent; each one gets its own copy on screen.
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

  /// For [SendFailure.tooFast]: how long the backend asked to wait.
  final Duration? retryAfter;

  /// A message that hit the daily limit cannot be retried until it resets,
  /// nor one sent with a session the backend rejected.
  bool get canRetry =>
      status == SendStatus.failed &&
      failure != SendFailure.dailyLimit &&
      failure != SendFailure.sessionEnded;
}

class MarlixEntry extends ChatEntry {
  MarlixEntry(this.message, {this.tone = MessageTone.neutral}) : super(message.id);

  final ChatMessage message;

  /// Tone of the message this one answers; only a reply just received has it.
  final MessageTone tone;
}

/// The crisis filter answered: shown prominently, never with a retry.
class CrisisEntry extends ChatEntry {
  CrisisEntry(this.message, this.resources) : super(message.id);

  final ChatMessage message;
  final List<HelpResource> resources;
}

/// What loading the history is doing; the screen shows each one differently.
/// [pending] is before the first request, so the chat is not shown as empty
/// for a moment.
enum HistoryStatus { pending, idle, loading, failed }

class ChatState {
  const ChatState({
    this.entries = const [],
    this.usage,
    this.limitResetsAt,
    this.historyStatus = HistoryStatus.pending,
    this.hasOlder = true,
  });

  /// Oldest first: the loaded history followed by this session's messages.
  final List<ChatEntry> entries;

  final HistoryStatus historyStatus;

  /// False once the oldest message was loaded. True until the first page says so.
  final bool hasOlder;

  /// Unknown until `GET /v1/usage` or the first reply answers.
  final Usage? usage;

  /// Set when the backend answered `DAILY_LIMIT_REACHED`.
  final DateTime? limitResetsAt;

  /// marlix is replying; the screen shows the typing indicator.
  bool get sending =>
      entries.any((entry) => entry is UserEntry && entry.status == SendStatus.sending);

  /// Lifts by itself after the reset, even if the app stays open past midnight.
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

  /// Where the next older page starts; null before the first page and at the end.
  String? _olderCursor;

  /// Starts empty for every session: another account never sees these messages.
  @override
  ChatState build() {
    ref.watch(signedInUserProvider);
    _olderCursor = null;
    return const ChatState();
  }

  MarlixApi get _api => ref.read(marlixApiProvider);

  /// Best effort: the remaining messages chip stays hidden if it fails.
  Future<void> loadUsage() async {
    try {
      final usage = await _api.usage();
      if (ref.mounted) state = state.copyWith(usage: usage);
    } on UnauthorizedException {
      if (ref.mounted) await _endSession();
    } on ApiException {
      // The next reply carries the usage too.
    }
  }

  /// Loads the newest page of the history, or the next older one if the chat
  /// already has messages. A failure leaves the chat usable and can be retried.
  Future<void> loadHistory() async {
    if (state.historyStatus == HistoryStatus.loading || !state.hasOlder) return;
    state = state.copyWith(historyStatus: HistoryStatus.loading);
    try {
      final page = await _api.history(before: _olderCursor);
      if (!ref.mounted) return;
      _olderCursor = page.nextCursor;
      // A message sent while the page was loading can already be in it.
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

  /// Shows the message right away and adds marlix's reply when it arrives.
  /// If sending fails, the message stays in the chat marked as failed, so
  /// the text is never lost.
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

  /// Sends a failed message again, in the same place in the chat.
  Future<void> retry(String id) async {
    final entry = state.entries.whereType<UserEntry>().where((e) => e.id == id).firstOrNull;
    if (entry == null || !entry.canRetry || state.sending) return;
    _replace(id, UserEntry(id, text: entry.text, status: SendStatus.sending));
    await _deliver(id, entry.text);
  }

  Future<void> _deliver(String id, String text) async {
    try {
      // Replies that will be read aloud come short and clean (S6-3).
      final mode = ref.read(repliesAreSpokenProvider) ? ChatMode.voice : ChatMode.text;
      final response = await _api.sendMessage(text, mode: mode);
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
      // Supabase refreshes the token by itself, so a rejected one means the
      // session really ended (expired, or the account was deleted).
      if (error is UnauthorizedException) await _endSession();
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
