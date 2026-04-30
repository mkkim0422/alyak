package kr.co.sphinfo.alyak.alyak

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/// FLAG_SECURE 정책:
/// - 릴리스 빌드 (debuggable=false): 항상 ON.
///   스크린샷, 화면 녹화, 최근 앱 미리보기에 가족 건강 정보가 노출되지 않도록 차단.
/// - 디버그 빌드 (debuggable=true): OFF.
///   QA 디바이스 테스트 시 스크린샷 캡처가 필요해 일부러 비활성.
///
/// 보조 보안:
/// - SecureAppShell (Flutter 측) 이 백그라운드 진입 시 BackdropFilter 로 블러 오버레이.
/// - SecureAppShell 이 5분 이상 background 후 복귀 시 PinLockScreen 강제.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val isDebuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        super.onCreate(savedInstanceState)
    }
}
