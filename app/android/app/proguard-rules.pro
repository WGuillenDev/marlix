# The voice engine (S6-2) reaches ONNX Runtime through JNI, so R8 must not rename it.
-keep class ai.onnxruntime.** { *; }
