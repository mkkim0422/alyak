import Flutter
import UIKit

/// FlutterSceneDelegate 를 상속해 lifecycle 콜백마다 native blur overlay 를
/// 스냅샷에 노출되지 않도록 즉시 깐다.
///
/// iOS 13+ scene-based lifecycle 에서는 AppDelegate 의 willResignActive 콜백
/// 이 backed 안 될 수 있어, scene 당 별도로 처리해야 안전하다. AppDelegate
/// 의 동일 로직과 함께 두면 single-scene/multi-scene 양쪽에서 보호.
class SceneDelegate: FlutterSceneDelegate {
  private var privacyOverlay: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    if let windowScene = scene as? UIWindowScene,
       let window = windowScene.windows.first {
      showPrivacyOverlay(on: window)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay(on window: UIWindow) {
    guard privacyOverlay == nil else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor(white: 0.94, alpha: 1.0)

    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = overlay.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.addSubview(blur)

    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
