# TFLite GPU delegate - prevent R8 from stripping missing GPU classes
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.** { *; }
