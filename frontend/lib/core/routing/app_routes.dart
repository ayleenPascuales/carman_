abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const verifyOtp = '/verify-otp';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const results = '/home/results';
  static const search = '/search';
  static const favorites = '/favorites';
  static const trips = '/trips';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const license = '/license';
  static const licenseReview = '/license/review';
  static const checkout = '/checkout';
  static const paymentMethods = '/payment-methods';
  static const bookingSuccess = '/booking/success';
  static const bookingFailed = '/booking/failed';
  static const bookingExpired = '/booking/expired';
  static const driver = '/driver';
  static const admin = '/admin';
  static const owner = '/owner';
  static const addVehicle = '/owner/add-vehicle';
  static const editProfile = '/profile/edit';
  static const map = '/map';

  static String vehicle(String id) => '/vehicle/$id';
  static String gallery(String id) => '/gallery/$id';
  static String trip(String id) => '/trip/$id';
}
