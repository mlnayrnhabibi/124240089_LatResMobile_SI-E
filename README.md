# [NIM]_LatResMobile_SI-E

Cara menjalankan:
1. `flutter create .`  (di folder ini, untuk membuat folder android/ios; lib/ & pubspec.yaml tidak tertimpa)
2. `flutter pub get`
3. Tambahkan di `android/app/src/main/AndroidManifest.xml`:
   - di dalam `<manifest>`: `<uses-permission android:name="android.permission.INTERNET"/>`
   - di dalam `<manifest>`: 
     `<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>`
4. `flutter run` (emulator / device)
