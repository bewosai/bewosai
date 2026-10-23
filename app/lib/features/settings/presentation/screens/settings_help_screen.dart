import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';

/// Settings → Help & Feedback: a help chat that answers how-to questions about
/// Bewosai only (backend superadmin/help_guide.py), a feedback form, and the
/// user's own messages with Super Admin's replies. Every question and message
/// shows on the Super Admin page.
class SettingsHelpScreen extends StatelessWidget {
  const SettingsHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & Feedback'),
          bottom: TabBar(
            labelColor: AppColors.orange,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.orange,
            tabs: const [Tab(text: 'Ask'), Tab(text: 'Send feedback'), Tab(text: 'Your messages')],
          ),
        ),
        body: const ResponsiveBody(
          child: TabBarView(children: [_HelpChat(), _FeedbackForm(), _MyMessages()]),
        ),
      ),
    );
  }
}

class _ChatLine {
  final bool mine;
  final String text;
  const _ChatLine(this.mine, this.text);
}

class _HelpChat extends StatefulWidget {
  const _HelpChat();
  @override
  State<_HelpChat> createState() => _HelpChatState();
}

class _HelpChatState extends State<_HelpChat> with AutomaticKeepAliveClientMixin {
  static const _starters = [
    'How do I make an invoice?',
    'How to add a product?',
    'How to record an expense?',
    'Where is the balance sheet?',
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lines = <_ChatLine>[
    const _ChatLine(false, 'Hi! Ask me how to do anything in Bewosai — sales, stock, parties, payments, expenses, reports, settings.'),
  ];
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _lines.add(_ChatLine(true, q));
      _busy = true;
    });
    String reply;
    try {
      final res = await ApiClient.instance.dio.post('/superadmin/help/ask/', data: {'question': q});
      reply = (res.data as Map<String, dynamic>)['answer']?.toString() ?? '';
    } catch (e) {
      reply = ApiClient.toApiException(e).message;
    }
    if (!mounted) return;
    setState(() {
      _lines.add(_ChatLine(false, reply));
      _busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              for (final line in _lines)
                Align(
                  alignment: line.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: line.mine ? AppColors.orange : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: line.mine ? null : Border.all(color: AppColors.navy100),
                    ),
                    child: Text(line.text, style: TextStyle(color: line.mine ? Colors.white : null)),
                  ),
                ),
              if (_lines.length == 1)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _starters.map((s) => ActionChip(label: Text(s), onPressed: () => _ask(s))).toList(),
                ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Thinking…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _ask,
                    decoration: const InputDecoration(hintText: 'Ask how to use Bewosai…', counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : () => _ask(_input.text),
                  icon: const Icon(Icons.send),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm();
  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      showAppSnackBar(context, 'Write a subject and a message', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.instance.dio.post('/superadmin/support/', data: {'subject': subject, 'message': message});
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      showAppSnackBar(context, 'Thanks! The Bewosai team will read it — replies show under Your messages.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.toApiException(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tell us about a problem, an idea, or anything about the app.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        TextField(controller: _subject, maxLength: 300, decoration: const InputDecoration(labelText: 'Subject *', counterText: '')),
        const SizedBox(height: 12),
        TextField(controller: _message, maxLength: 5000, minLines: 4, maxLines: 8,
            decoration: const InputDecoration(labelText: 'Message *', alignLabelWithHint: true)),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Send feedback', isLoading: _sending, onPressed: _sending ? null : _send),
      ],
    );
  }
}

class _MyMessages extends StatefulWidget {
  const _MyMessages();
  @override
  State<_MyMessages> createState() => _MyMessagesState();
}

class _MyMessagesState extends State<_MyMessages> {
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get('/superadmin/my-tickets/');
      final data = res.data;
      final list = (data is Map<String, dynamic> ? data['results'] : data) as List? ?? [];
      if (mounted) setState(() => _rows = list.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return EmptyState(icon: Icons.error_outline, title: _error!);
    final rows = _rows;
    if (rows == null) return const LoadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(children: const [SizedBox(height: 80), EmptyState(icon: Icons.mail_outline, title: 'No messages yet')])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = rows[i];
                final reply = (t['admin_reply'] ?? '').toString();
                final created = Formatters.parseDate(t['created_at']?.toString());
                return AppSectionCard(children: [
                  Row(children: [
                    Expanded(child: Text((t['subject'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                    StatusBadge(label: (t['status'] ?? '').toString().replaceAll('_', ' '), color: AppColors.navy500),
                  ]),
                  if (created != null)
                    Text(Formatters.date(created), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text((t['message'] ?? '').toString()),
                  if (reply.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text('Bewosai team: $reply'),
                    ),
                  ],
                ]);
              },
            ),
    );
  }
}
