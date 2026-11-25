/// Asset registry. Keeping paths in one place avoids typo-driven blank images.
abstract final class AppAssets {
  // Brand & hero.
  static const heroPorsche = 'assets/images/cars/hero_porsche.jpg';
  static const sportsCar = 'assets/images/cars/sports_car.jpg';

  // Vehicles.
  static const teslaModelY = 'assets/images/cars/tesla_model_y.jpg';
  static const teslaModelYDetail =
      'assets/images/cars/tesla_model_y_detail.jpg';
  static const teslaModelYCheckout =
      'assets/images/cars/tesla_model_y_checkout.jpg';
  static const teslaModel3 = 'assets/images/cars/tesla_model_3.jpg';
  static const cupraFormentor = 'assets/images/cars/cupra_formentor.jpg';
  static const cupraFormentor2 = 'assets/images/cars/cupra_formentor_2.jpg';
  static const audiQ3 = 'assets/images/cars/audi_q3.jpg';
  static const teslaWhiteShowroom =
      'assets/images/cars/tesla_white_showroom.jpg';
  static const teslaRejected = 'assets/images/cars/tesla_rejected.jpg';
  static const teslaProto = 'assets/images/cars/tesla_proto.jpg';
  static const cupraProto = 'assets/images/cars/cupra_proto.jpg';
  static const teslaDetailProto = 'assets/images/cars/tesla_detail_proto.jpg';
  static const teslaMini = 'assets/images/cars/tesla_mini.jpg';

  // Gallery.
  static const teslaInterior = 'assets/images/cars/tesla_interior_1.jpg';
  static const teslaFront = 'assets/images/cars/tesla_front.jpg';
  static const teslaSide = 'assets/images/cars/tesla_side.jpg';
  static const teslaDashboard = 'assets/images/cars/tesla_dashboard.jpg';
  static const teslaRear = 'assets/images/cars/tesla_rear.jpg';
  static const teslaRearSeats = 'assets/images/cars/tesla_rear_seats.jpg';
  static const teslaTrunk = 'assets/images/cars/tesla_trunk.jpg';
  static const teslaCharger = 'assets/images/cars/tesla_charger.jpg';

  // People.
  static const avatarUser = 'assets/images/people/avatar_user.jpg';
  static const avatarElena = 'assets/images/people/avatar_elena.jpg';
  static const avatarElenaAlt = 'assets/images/people/avatar_elena_2.jpg';

  // Misc.
  static const mapMadrid = 'assets/images/misc/map_madrid.jpg';
  static const mapProto = 'assets/images/misc/map_proto.jpg';
  static const licenseSample = 'assets/images/misc/license_sample.jpg';

  static const teslaGallery = [
    teslaModelYDetail,
    teslaInterior,
    teslaFront,
    teslaSide,
    teslaDashboard,
    teslaRear,
    teslaRearSeats,
    teslaTrunk,
  ];

  static const fallbackVehicle = teslaModelY;
}
