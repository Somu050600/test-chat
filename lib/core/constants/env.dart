class Env {
  Env._();

  static const firebaseWebApiKey =
      String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const firebaseWebAuthDomain =
      String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  static const firebaseWebAppId =
      String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const firebaseWebMeasurementId =
      String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

  static const firebaseAndroidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const firebaseAndroidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  static const googleSignInClientId =
      String.fromEnvironment('GOOGLE_SIGN_IN_CLIENT_ID');
  static const fcmVapidKey =
      String.fromEnvironment('FCM_VAPID_KEY');

  static const notifyApiUrl =
      String.fromEnvironment('NOTIFY_API_URL');
}
