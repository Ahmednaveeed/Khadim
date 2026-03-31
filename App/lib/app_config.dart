enum AppFlavor {
  customer,
  kiosk,
}

class AppConfig {
  static AppFlavor flavor = AppFlavor.customer;

  static bool get isKiosk => flavor == AppFlavor.kiosk;
  static bool get isCustomer => flavor == AppFlavor.customer;
}
