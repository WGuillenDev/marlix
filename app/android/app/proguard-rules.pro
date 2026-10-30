# The voice engine (S6-2) reaches ONNX Runtime through JNI, so R8 must not rename it.
-keep class ai.onnxruntime.** { *; }

# The voice activity detector (S6-9) looks its Kotlin classes up by name from native code (JNI FindClass), so R8 must not rename or strip them.
-keep class dev.miracle.vad_plus.** { *; }
