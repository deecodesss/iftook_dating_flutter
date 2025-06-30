# This file includes rules generated from the missing_rules.txt file

# Keep Jackson serialization components
-keep class com.fasterxml.jackson.databind.ext.** { *; }

# Keep OkHttp platform classes
-keep class okhttp3.internal.platform.** { *; }
