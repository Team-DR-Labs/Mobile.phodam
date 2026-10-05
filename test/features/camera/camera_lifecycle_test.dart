import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/features/camera/presentation/camera_widgets.dart';

void main() {
  CameraLifecycleAction act(
    AppLifecycleState state, {
    bool hasController = false,
    bool initializing = false,
    bool fakeCamera = false,
  }) =>
      cameraLifecycleAction(
        state,
        hasController: hasController,
        initializing: initializing,
        fakeCamera: fakeCamera,
      );

  test('비활성이 되면 카메라를 놓는다', () {
    expect(act(AppLifecycleState.inactive, hasController: true),
        CameraLifecycleAction.release);
    expect(act(AppLifecycleState.inactive), CameraLifecycleAction.none);
  });

  test('놓은 뒤 복귀하면 다시 연다(셔터 영구 비활성 방지)', () {
    expect(act(AppLifecycleState.resumed), CameraLifecycleAction.reinitialize);
  });

  test('이미 열려 있거나 여는 중이거나 가짜 카메라면 다시 열지 않는다', () {
    expect(act(AppLifecycleState.resumed, hasController: true),
        CameraLifecycleAction.none);
    expect(act(AppLifecycleState.resumed, initializing: true),
        CameraLifecycleAction.none);
    expect(act(AppLifecycleState.resumed, fakeCamera: true),
        CameraLifecycleAction.none);
  });
}
