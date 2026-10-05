# Reglas exigidas por flutter_stripe (README, paso 7). Sin ellas la compilación release falla en R8
# con "Missing classes detected" por clases opcionales del SDK de Stripe.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.google.android.gms.tapandpay.**
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize
-keep class com.stripe.** { *; }
