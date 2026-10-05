import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/error_view.dart';
import '../../camera/data/upload_queue.dart';
import '../../date/presentation/date_controller.dart';
import 'caption_field.dart';
import 'photo_picker_grid.dart';
import 'submit_photos.dart';

/// 대표 사진 한 장과 선택적인 글을 제출한다.
///
/// 제출 전 사진은 앱 안에서 보기만 한다. 저장·공유 UI 를 두지 않는다.
class SubmitPage extends ConsumerStatefulWidget {
  const SubmitPage({super.key, required this.dateId});

  final String dateId;

  @override
  ConsumerState<SubmitPage> createState() => _SubmitPageState();
}

class _SubmitPageState extends ConsumerState<SubmitPage> {
  final _caption = TextEditingController();
  String? _selectedId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 남은 업로드가 있으면 백오프를 기다리지 않고 바로 시도한다.
    ref.read(uploadQueueProvider.notifier).process(force: true);
  }

  Future<void> _refresh() async {
    await ref.read(uploadQueueProvider.notifier).process(force: true);
    ref.invalidate(myServerPhotosProvider(widget.dateId));
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<bool> _confirm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이대로 제출할까요?'),
        content: const Text('제출 후 수정할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제출'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    final photoId = _selectedId;
    if (photoId == null || !await _confirm()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(dateActionsProvider)
          .submit(
            widget.dateId,
            photoId: photoId,
            caption: normalizeCaption(_caption.text),
          );
      if (mounted) {
        context.go(
          Uri(
            path: AppRoutes.develop(widget.dateId),
            queryParameters: {'photo': photoId},
          ).toString(),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, e.userMessage);
      if (e.code == ApiErrorCode.dateNotActive) context.go(AppRoutes.home);
      if (e.code == ApiErrorCode.alreadySubmitted) {
        context.go(AppRoutes.receive(widget.dateId));
      }
      if (e.code == ApiErrorCode.photoNotUploaded) {
        ref.invalidate(myServerPhotosProvider(widget.dateId));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(selectablePhotosProvider(widget.dateId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('대표 사진 고르기')),
      body: photos.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(selectablePhotosProvider(widget.dateId)),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                items.isEmpty
                    ? '아직 찍은 사진이 없어요.'
                    : '상대에게 보여줄 한 장을 골라 주세요. 나머지 사진은 제출 후 받을 수 있어요.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              PhotoPickerGrid(
                photos: items,
                selectedId: _selectedId,
                onSelect: (id) => setState(() => _selectedId = id),
              ),
              const SizedBox(height: 16),
              CaptionField(controller: _caption),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('submitButton'),
                onPressed: _selectedId == null || _submitting ? null : _submit,
                child: const Text('제출하기'),
              ),
              const SizedBox(height: 8),
              Text(
                '제출 후에는 사진과 글을 수정할 수 없어요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
