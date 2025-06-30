# Add these rules to fix the R8 missing classes error

# Jackson related
-dontwarn com.fasterxml.jackson.databind.ext.Java7SupportImpl
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient

# OkHttp related
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE

# DOM related
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
