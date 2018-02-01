/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class com_breadwallet_core_BRCorePaymentProtocolPayment */

#ifndef _Included_com_breadwallet_core_BRCorePaymentProtocolPayment
#define _Included_com_breadwallet_core_BRCorePaymentProtocolPayment
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    getMerchantData
 * Signature: ()[B
 */
JNIEXPORT jbyteArray JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_getMerchantData
  (JNIEnv *, jobject);

/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    getTransactions
 * Signature: ()[Lcom/breadwallet/core/BRCoreTransaction;
 */
JNIEXPORT jobjectArray JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_getTransactions
  (JNIEnv *, jobject);

/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    getRefundTo
 * Signature: ()[Lcom/breadwallet/core/BRCoreTransactionOutput;
 */
JNIEXPORT jobjectArray JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_getRefundTo
  (JNIEnv *, jobject);

/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    getMemo
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_getMemo
  (JNIEnv *, jobject);

/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    createPaymentProtocolPayment
 * Signature: ([B)J
 */
JNIEXPORT jlong JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_createPaymentProtocolPayment
  (JNIEnv *, jclass, jbyteArray);

/*
 * Class:     com_breadwallet_core_BRCorePaymentProtocolPayment
 * Method:    disposeNative
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_breadwallet_core_BRCorePaymentProtocolPayment_disposeNative
  (JNIEnv *, jobject);

#ifdef __cplusplus
}
#endif
#endif
