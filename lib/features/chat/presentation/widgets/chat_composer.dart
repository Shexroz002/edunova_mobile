import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/message_models.dart';

/// Maps a file extension onto the mime type the upload endpoint accepts.
///
/// The server validates `content-type` against its own allow-list, so an
/// unknown extension is rejected here rather than after a pointless upload.
String? mimeTypeForPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    'wav' => 'audio/wav',
    'm4a' || 'aac' => 'audio/mp4',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    'zip' => 'application/zip',
    '7z' => 'application/x-7z-compressed',
    'rar' => 'application/vnd.rar',
    _ => null,
  };
}

/// Message input: reply/edit banner, attach, text field, send and voice.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onTyping,
    this.replyTo,
    this.editing,
    this.onCancelContext,
    this.currentUserId,
  });

  final void Function(String text) onSend;

  /// [kind] overrides the type derived from the mime type — a recorded clip is
  /// a `voice` note, not generic `audio`.
  final void Function(File file, String mimeType, AttachmentKind? kind) onAttach;
  final VoidCallback onTyping;

  /// Message being replied to, shown above the field.
  final Message? replyTo;

  /// Message being edited; its text seeds the field.
  final Message? editing;
  final VoidCallback? onCancelContext;
  final int? currentUserId;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorder();

  bool _hasText = false;

  /// Path of the clip being recorded, or `null` when idle.
  String? _recordingPath;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  /// True while a start/stop is in flight.
  ///
  /// Both transitions await the platform recorder, and the send button sits
  /// exactly where the mic button reappears — without this guard one tap could
  /// stop a clip and immediately start another, posting two notes.
  bool _busy = false;

  bool get _recording => _recordingPath != null;

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editing = widget.editing;
    if (editing != null && editing.id != oldWidget.editing?.id) {
      _controller.text = editing.text ?? '';
      _hasText = _controller.text.trim().isNotEmpty;
      _focus.requestFocus();
    }
    if (editing == null && oldWidget.editing != null) {
      _controller.clear();
      _hasText = false;
    }
    if (widget.replyTo != null && widget.replyTo?.id != oldWidget.replyTo?.id) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final has = value.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (has) widget.onTyping();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  // ── Voice ──────────────────────────────────────────────────────────────

  /// Starts recording after asking for the microphone.
  Future<void> _startRecording() async {
    if (_busy || _recording) return;
    _busy = true;
    try {
      await _beginRecording();
    } finally {
      _busy = false;
    }
  }

  Future<void> _beginRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofonga ruxsat berilmadi')),
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';

    // AAC in an m4a container is `audio/mp4`, which the upload allow-list takes.
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;

    setState(() {
      _recordingPath = path;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  /// Stops recording and sends the clip as a voice note.
  Future<void> _stopAndSend() async {
    if (_busy || !_recording) return;
    _busy = true;
    try {
      await _finishRecording();
    } finally {
      _busy = false;
    }
  }

  Future<void> _finishRecording() async {
    final path = await _recorder.stop();
    _ticker?.cancel();
    final tooShort = _elapsed.inMilliseconds < 800;
    if (!mounted) return;
    setState(() {
      _recordingPath = null;
      _elapsed = Duration.zero;
    });

    if (path == null) return;
    final file = File(path);
    // A stray tap produces an unplayable sliver; drop it rather than post it,
    // but say so — a silently discarded recording reads as a broken button.
    if (tooShort) {
      await file.delete().catchError((_) => file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Juda qisqa — mikrofonni bosib turing')),
      );
      return;
    }
    widget.onAttach(file, 'audio/mp4', AttachmentKind.voice);
  }

  /// Aborts the recording and removes the file.
  Future<void> _cancelRecording() async {
    if (_busy || !_recording) return;
    _busy = true;
    final path = await _recorder.stop();
    _ticker?.cancel();
    if (path != null) {
      final file = File(path);
      await file.delete().catchError((_) => file);
    }
    _busy = false;
    if (!mounted) return;
    setState(() {
      _recordingPath = null;
      _elapsed = Duration.zero;
    });
  }

  // ── Attachments ────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    widget.onAttach(File(picked.path), mimeTypeForPath(picked.path) ?? 'image/jpeg', null);
  }

  /// Picks or records a clip.
  ///
  /// A clip recorded with the camera is sent as a `video_message` — the round
  /// bubble that plays in place — while one chosen from the gallery stays a
  /// normal rectangular video.
  Future<void> _pickVideo(ImageSource source, {required AttachmentKind kind}) async {
    final round = kind == AttachmentKind.videoMessage;
    final picked = await ImagePicker().pickVideo(
      source: source,
      // Round messages are short by nature, as they are on Telegram.
      maxDuration: round ? const Duration(minutes: 1) : const Duration(minutes: 5),
    );
    if (picked == null) return;
    final mime = mimeTypeForPath(picked.path) ?? 'video/mp4';
    widget.onAttach(File(picked.path), mime, kind);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final path = result?.files.single.path;
    if (path == null) return;
    final mime = mimeTypeForPath(path);
    if (mime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu turdagi fayl qabul qilinmaydi')),
      );
      return;
    }
    widget.onAttach(File(path), mime, null);
  }

  Future<void> _openAttachMenu() async {
    final c = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bgCard,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              (Icons.image_outlined, 'Rasm', () => _pickImage(ImageSource.gallery)),
              (
                Icons.videocam_outlined,
                'Video',
                () => _pickVideo(ImageSource.gallery, kind: AttachmentKind.video)
              ),
              (Icons.photo_camera_outlined, 'Suratga olish',
                  () => _pickImage(ImageSource.camera)),
              (
                Icons.motion_photos_on_outlined,
                'Video xabar',
                () => _pickVideo(ImageSource.camera, kind: AttachmentKind.videoMessage)
              ),
              (Icons.insert_drive_file_outlined, 'Fayl', _pickFile),
            ])
              ListTile(
                leading: Icon(option.$1, color: c.accent),
                title: Text(option.$2),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  option.$3();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final banner = widget.editing ?? widget.replyTo;

    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (banner != null && !_recording)
              _ContextBanner(
                editing: widget.editing != null,
                message: banner,
                onCancel: widget.onCancelContext,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: _recording
                  ? _RecordingBar(
                      elapsed: _elapsed,
                      onCancel: _cancelRecording,
                      onSend: _stopAndSend,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _openAttachMenu,
                          icon: const Icon(Icons.attach_file_rounded, size: 23),
                          color: c.textSecondary,
                          tooltip: 'Biriktirish',
                        ),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            decoration: BoxDecoration(
                              color: c.bgInner,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: c.border),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              onChanged: _onChanged,
                              onSubmitted: (_) => _send(),
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(fontSize: 14.5, color: c.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Xabar yozing...',
                                hintStyle: TextStyle(fontSize: 14.5, color: c.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SendButton(
                          hasText: _hasText,
                          onSend: _send,
                          onRecord: _startRecording,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the input row while a voice note is being recorded.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.elapsed,
    required this.onCancel,
    required this.onSend,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  String get _clock {
    final minutes = elapsed.inMinutes;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline_rounded, size: 23),
          color: AppColors.error,
          tooltip: 'Bekor qilish',
        ),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.error, 0x14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.tint(AppColors.error, 0x4D)),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(
                  _clock,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Yozilmoqda...',
                    style: TextStyle(fontSize: 13.5, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, size: 21, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Red dot that breathes while recording.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(_animation),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      ),
    );
  }
}

/// Strip above the field while replying or editing.
class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.editing, required this.message, this.onCancel});

  final bool editing;
  final Message message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = message.text?.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(editing ? Icons.edit_rounded : Icons.reply_rounded, size: 17, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Tahrirlash' : 'Javob berish',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
                Text(
                  text == null || text.isEmpty ? 'Biriktirma' : text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: c.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Sends the typed text, or starts a voice note when the field is empty.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.hasText,
    required this.onSend,
    required this.onRecord,
  });

  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasText ? onSend : onRecord,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
        child: Icon(
          hasText ? Icons.send_rounded : Icons.mic_none_rounded,
          size: 21,
          color: Colors.white,
        ),
      ),
    );
  }
}
