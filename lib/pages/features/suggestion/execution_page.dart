import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../constants/color_constants.dart';
import '../../../constants/view_page_id.dart';
import '../../../log.dart';
import '../../../models/common/loading_state.dart';
import '../../../providers/features/user/auth/dosuka_auth_provider.dart';
import '../../../utils/api/suggestion_api.dart';
import '../../../widgets/common/dosuka_scaffold.dart';

/// 旅行提案実行ページ。
/// lang-chain-studyのAPIに質問を投げて旅行提案を受け取る。
class ExecutionPage extends StatefulWidget {
  const ExecutionPage({super.key});

  @override
  ExecutionPageState createState() => ExecutionPageState();
}

class ExecutionPageState extends State<ExecutionPage> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  LoadingState _loadingState = LoadingState.loaded;

  final SuggestionApi _api = SuggestionApi();

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final String question = _questionController.text.trim();
    if (question.isEmpty) return;
    if (_loadingState == LoadingState.loading) return;

    _questionController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _loadingState = LoadingState.loading;
    });
    _scrollToBottom();

    final authProvider = context.read<DosukAuthProvider>();
    final String? idToken = await authProvider.getIdToken();

    try {
      final SuggestionResult result = idToken != null
          ? await _api.search(question: question, idToken: idToken)
          : SuggestionResult(
              question: question,
              answer: await _api.chat(question: question),
              sources: [],
            );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: result.answer,
          isUser: false,
          sources: result.sources,
        ));
        _loadingState = LoadingState.loaded;
      });
      _scrollToBottom();
    } on SuggestionApiException catch (e) {
      logger.w(e);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: e.message,
          isUser: false,
          isError: true,
        ));
        _loadingState = LoadingState.loaded;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _signOut() async {
    final authProvider = context.read<DosukAuthProvider>();
    await authProvider.signOut();
    if (!mounted) return;
    context.goNamed(ViewPageId.login.pageName);
  }

  @override
  Widget build(BuildContext context) {
    return DosukScaffold(
      title: '旅、どうすか？',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'ログアウト',
          onPressed: _signOut,
        ),
      ],
      child: Column(
        children: [
          Expanded(child: _buildMessageList()),
          const SizedBox(height: 8),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length + (_loadingState == LoadingState.loading ? 1 : 0),
      itemBuilder: (BuildContext ctx, int index) {
        if (index == _messages.length) {
          return _buildLoadingBubble();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 64,
            color: ColorConstants.themeColor,
          ),
          SizedBox(height: 16),
          Text(
            '旅行について何でも聞いてください',
            style: TextStyle(
              fontSize: 16,
              color: ColorConstants.titleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '例: 温泉でゆっくりできる旅先を提案して',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isError
                    ? Colors.red.shade100
                    : message.isUser
                        ? ColorConstants.themeColor
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            if (message.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  '参考: ${message.sources.join(', ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 48,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorConstants.themeColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: '旅行について質問してみましょう...',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendQuestion(),
            ),
          ),
          IconButton(
            onPressed:
                _loadingState == LoadingState.loading ? null : _sendQuestion,
            icon: const Icon(Icons.send),
            color: ColorConstants.themeColor,
            tooltip: '送信',
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final List<String> sources;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.sources = const [],
  });
}
