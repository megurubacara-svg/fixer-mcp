import 'package:flutter/material.dart';

import 'netrunner_thread_models.dart';
import 'netrunner_thread_repository.dart';

const _threadInk = Color(0xFF172033);
const _threadMuted = Color(0xFF68738A);
const _threadBorder = Color(0xFFD9E0EC);
const _threadCanvas = Color(0xFFF6F7FB);
const _threadBlue = Color(0xFF2A6CF0);

class NetrunnerThreadPanel extends StatefulWidget {
  const NetrunnerThreadPanel({
    super.key,
    required this.sessionId,
    required this.repository,
  });

  final int sessionId;
  final NetrunnerThreadRepository repository;

  @override
  State<NetrunnerThreadPanel> createState() => _NetrunnerThreadPanelState();
}

class _NetrunnerThreadPanelState extends State<NetrunnerThreadPanel> {
  late Future<NetrunnerThreadSnapshot> _threadFuture;
  late final TextEditingController _composerController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _threadFuture = widget.repository.loadThread(widget.sessionId);
  }

  @override
  void didUpdateWidget(covariant NetrunnerThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _composerController.clear();
      _threadFuture = widget.repository.loadThread(widget.sessionId);
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _threadFuture = widget.repository.loadThread(widget.sessionId);
    });
  }

  Future<void> _send(NetrunnerThreadSnapshot thread) async {
    final message = _composerController.text.trim();
    if (message.isEmpty || _sending || !thread.continuation.supported) return;
    setState(() => _sending = true);
    try {
      final result = await widget.repository.sendFollowUp(
        widget.sessionId,
        message,
      );
      if (!mounted) return;
      _composerController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? 'Follow-up started.' : result.message,
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _threadCanvas,
      child: FutureBuilder<NetrunnerThreadSnapshot>(
        future: _threadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ThreadErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final thread = snapshot.requireData;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 900
                  ? 32.0
                  : 16.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ThreadHeader(thread: thread, onRefresh: _reload),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        20,
                      ),
                      children: [
                        if (thread.isAwaitingBackend)
                          const _ThreadNotice(
                            icon: Icons.rocket_launch_outlined,
                            title: 'Choose a backend to launch this Netrunner',
                            message:
                                'This is a pending manual session. It has no provider thread yet and has not been launched.',
                          )
                        else ...[
                          _TranscriptBody(thread: thread),
                          if (!thread.continuation.supported)
                            _ThreadNotice(
                              icon: Icons.info_outline,
                              title: 'Follow-up is unavailable',
                              message: thread.continuation.reason,
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (thread.continuation.supported)
                    _ThreadComposer(
                      controller: _composerController,
                      sending: _sending,
                      onSend: () => _send(thread),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.thread, required this.onRefresh});

  final NetrunnerThreadSnapshot thread;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final backendLabel = thread.backend.isEmpty ? 'No backend' : thread.backend;
    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _threadBorder)),
        ),
        child: Row(
          children: [
            const Icon(Icons.forum_outlined, color: _threadBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Netrunner #${thread.localId} thread',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _threadInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _ThreadChip(label: backendLabel),
                      _ThreadChip(
                        label: thread.launchState.replaceAll('_', ' '),
                      ),
                      if (thread.model.isNotEmpty)
                        _ThreadChip(label: thread.model),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh provider thread',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptBody extends StatelessWidget {
  const _TranscriptBody({required this.thread});

  final NetrunnerThreadSnapshot thread;

  @override
  Widget build(BuildContext context) {
    if (thread.messages.isNotEmpty) {
      return Column(
        children: [
          for (final message in thread.messages)
            _MessageBubble(message: message),
        ],
      );
    }
    final message = switch (thread.transcriptAvailability) {
      'metadata_only' =>
        'The provider session is linked, but this provider does not expose a readable dashboard transcript yet.',
      'missing' =>
        'The provider session is linked, but its local transcript file could not be found.',
      'empty' =>
        'The linked transcript does not contain user or assistant messages yet.',
      _ => 'No provider messages are available for this session yet.',
    };
    return _ThreadNotice(
      icon: Icons.subject_outlined,
      title: 'Transcript ${thread.transcriptAvailability.replaceAll('_', ' ')}',
      message: message,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final NetrunnerThreadMessageRecord message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.role == 'user';
    return Semantics(
      label: '${fromUser ? 'Architect' : 'Netrunner'} message',
      child: Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fromUser ? const Color(0xFFEAF1FF) : Colors.white,
            border: Border.all(color: _threadBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromUser ? 'Architect' : 'Netrunner',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fromUser ? _threadBlue : _threadMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              SelectableText(
                message.text,
                style: const TextStyle(color: _threadInk, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadComposer extends StatelessWidget {
  const _ThreadComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _threadBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('netrunner-thread-composer'),
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Follow up in this provider thread',
                    hintText:
                        'Ask the Netrunner to inspect, explain, or rerun…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('netrunner-thread-send'),
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(sending ? 'Sending' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadNotice extends StatelessWidget {
  const _ThreadNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _threadBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _threadMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(color: _threadMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadChip extends StatelessWidget {
  const _ThreadChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _threadCanvas,
        border: Border.all(color: _threadBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: _threadMuted),
      ),
    );
  }
}

class _ThreadErrorState extends StatelessWidget {
  const _ThreadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 34),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
