class AppConstant {
  static const String appName = 'RideMatch';

  // Backward-compatible alias used in some older widgets.
  static const String AppName = appName;

  // Common remote placeholders used across chat/ride/profile cards.
  static const String defaultProfileImage =
      'https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png';
  static const String defaultChatAvatar = 'https://i.pravatar.cc/150?img=3';
}

class AppEndpoints {
  // Auth
  static const String authSignup = '/api/auth/signup';
  static const String authLogin = '/api/auth/login';
  static const String authMe = '/api/auth/me';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authVerifyOtp = '/api/auth/verify-otp';
  static const String authResetPassword = '/api/auth/reset-password';
  static const String authUpdateProfile = '/api/auth/update-profile';

  // Rides / bookings / requests
  static const String rides = '/api/rides';
  static const String ridesNearby = '/api/rides/nearby';
  static const String rideRequestsNearby = '/api/rides/requests/nearby/list';
  static String rideRequestsByUser(String userId) =>
      '/api/rides/requests/$userId';
  static String rideRespond(String rideId) => '/api/rides/$rideId/respond';
  static String rideIncoming(String driverId) =>
      '/api/rides/incoming/$driverId';
  static String rideRequest(String rideId) => '/api/rides/$rideId/request';
  static String rideByUser(String userId) => '/api/rides/user/$userId';
  static String rideCancel(String rideId) => '/api/rides/$rideId/cancel';

  static const String bookings = '/api/bookings';
  static const String bookingsMe = '/api/bookings/me';

  // Chat / messages / users
  static String chatPermission(String senderId, String receiverId) =>
      '/api/chat/permission/$senderId/$receiverId';
  static String userById(String userId) => '/api/users/$userId';
  static String messages(String senderId, String receiverId) =>
      '/api/messages/$senderId/$receiverId';
  static const String messageSend = '/api/messages/send';
  static const String messageAutoIntro = '/api/messages/auto-intro';
  static String chatHistory(String userId) => '/api/chathistory/$userId';

  // Notifications
  static String notifications(String userId) => '/api/notifications/$userId';
  static const String notificationsLike = '/api/notifications/like';
  static String notificationsMarkAllRead(String userId) =>
      '/api/notifications/mark-read/$userId';
  static String notificationsUnreadCount(String userId) =>
      '/api/notifications/unread/count/$userId';
  static String notificationMarkRead(String notificationId) =>
      '/api/notifications/$notificationId/read';

  // Profile
  static const String profileUpload = '/api/profile/upload-profile';
  static const String profileUploadVerification =
      '/api/profile/upload-verification';

  // Payments
  static const String paymentMethods = '/api/payments/methods';
  static const String paymentTransactions = '/api/payments/transactions';

  // Admin
  static const String adminUsers = '/api/admin/users';
  static const String adminRides = '/api/admin/rides';
  static const String adminRideRequests = '/api/admin/ride-requests';
  static const String adminPaymentMethods = '/api/admin/payment-methods';
  static const String adminPayments = '/api/admin/payments';
  static const String adminNotifications = '/api/admin/notifications';
  static const String adminBanners = '/api/admin/banners';
  static const String adminTerms = '/api/admin/terms';
}
