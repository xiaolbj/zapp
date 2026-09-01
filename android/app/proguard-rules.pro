# Native code looks these members up by their Java names through JNI.
-keep class com.xiaolbj.zapp.ZappActivity { *; }
-keep class com.xiaolbj.zapp.ZappActivity$* { *; }

-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
