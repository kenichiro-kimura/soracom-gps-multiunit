# soratun_bridge.cpp resolves JNI methods by their exported Java_<package> symbols.
# Keep the JNI class and native method names; other app code can be obfuscated.
-keep,allowoptimization class org.sokohiki.kimura.app.soracom.gpsmultiunit.LibsoratunJni {
    native <methods>;
}
