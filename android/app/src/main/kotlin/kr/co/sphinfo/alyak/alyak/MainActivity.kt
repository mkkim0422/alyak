package kr.co.sphinfo.alyak.alyak

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // TODO(security): re-enable FLAG_SECURE before production release.
        // Disabled during testing so screenshots / screen recording work.
        // To restore:
        //   import android.view.WindowManager
        //   window.setFlags(
        //       WindowManager.LayoutParams.FLAG_SECURE,
        //       WindowManager.LayoutParams.FLAG_SECURE,
        //   )
        super.onCreate(savedInstanceState)
    }
}
