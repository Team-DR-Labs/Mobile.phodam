import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/config/env.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../date/presentation/date_controller.dart';
import '../../me/presentation/me_controller.dart';
import '../data/film_look.dart';
import '../data/models/queued_photo.dart';
import '../data/upload_queue.dart';
import 'camera_widgets.dart';
import 'shot_controller.dart';

/// 필름 카메라. ISO·노출 등 세부 조작은 MVP 범위가 아니다.
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key, required this.dateId});

  final String dateId;

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _cameraError;

  /// 카메라가 없는 기기(시뮬레이터)에서 개발용으로 다미 이미지를 찍는다.
  bool _fakeCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _fakeCamera = !Env.isProd;
          if (Env.isProd) _cameraError = '사용할 수 있는 카메라가 없어요.';
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      ref.read(appLoggerProvider).w('카메라 초기화 실패', error: e);
      if (!mounted) return;
      setState(() => _cameraError = e.code.contains('AccessDenied')
          ? '설정에서 카메라 권한을 허용해 주세요.'
          : '카메라를 열 수 없어요.');
    } catch (e) {
      ref.read(appLoggerProvider).w('카메라를 쓸 수 없음', error: e);
      if (!mounted) return;
      setState(() {
        _fakeCamera = !Env.isProd;
        if (Env.isProd) _cameraError = '카메라를 열 수 없어요.';
      });
    }
  }

  Future<Uint8List> _capture() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await File(file.path).delete().catchError((_) => File(file.path));
      return bytes;
    }
    final data = await rootBundle.load(Dami.asset);
    return data.buffer.asUint8List();
  }

  Future<void> _shoot() async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(shotControllerProvider(widget.dateId).notifier);
    final result = await notifier.shoot(_capture);
    if (!mounted) return;
    switch (result) {
      case ShotSaved():
        break;
      case ShotRejected(:final error) when result.dateClosed:
        showMessage(context, error.userMessage);
        ref.read(meControllerProvider.notifier).reload();
        context.go(AppRoutes.home);
      case ShotRejected(:final error):
        showMessage(context, error.userMessage);
      case ShotCaptureFailed():
        showMessage(context, '촬영에 실패했어요. 사용한 필름은 돌아오지 않아요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(dateDetailProvider(widget.dateId)).value;
    final film = ref.watch(meControllerProvider).value?.filmBalance ?? 0;
    final online = ref.watch(onlineProvider).value ?? true;
    final busy = ref.watch(shotControllerProvider(widget.dateId));
    final queue = (ref.watch(uploadQueueProvider).value ?? const <QueuedPhoto>[])
        .forDate(widget.dateId);
    final canShoot = date != null && date.canShoot(ref.watch(clockProvider)());
    final ready = _controller != null || _fakeCamera;
    final enabled = canShoot && ready && online && film > 0 && !busy;

    return Scaffold(
      backgroundColor: AppColors.body,
      body: SafeArea(
        child: Column(
          children: [
            CameraTopBar(
              title: date?.me.topic?.title ?? date?.theme.title ?? '',
              filmBalance: film,
            ),
            Expanded(child: _viewfinder()),
            CameraNotice(
              message: !online
                  ? '오프라인에서는 촬영할 수 없어요.'
                  : film <= 0
                      ? '남은 필름이 없어요.'
                      : _fakeCamera
                          ? '개발용: 카메라가 없어 다미 사진으로 촬영해요.'
                          : null,
            ),
            CameraBottomBar(
              lastShot: queue.isEmpty ? null : queue.last.filePath,
              pendingCount:
                  queue.where((q) => q.status == QueueStatus.pending).length,
              shutterEnabled: enabled,
              busy: busy,
              onShutter: _shoot,
              onPick: () => context.push(AppRoutes.submit(widget.dateId)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder() {
    final controller = _controller;
    final Widget content;
    if (controller != null && controller.value.isInitialized) {
      content = CameraPreview(controller);
    } else if (_fakeCamera) {
      content = Image.asset(Dami.asset, fit: BoxFit.cover);
    } else {
      content = Center(
        child: _cameraError == null
            ? const CircularProgressIndicator()
            : Text(_cameraError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(FilmLook.matrix),
            child: content,
          ),
        ),
      ),
    );
  }
}
