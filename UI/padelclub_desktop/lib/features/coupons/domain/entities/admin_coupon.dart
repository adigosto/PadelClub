/// The administrator-facing coupon snapshot returned by `/Commerce/coupons`.
///
/// Values are deliberately kept as the API reports them. A save always
/// refetches this list rather than trying to predict redemption counts or
/// validity locally.
class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    required this.minimumOrderAmount,
    required this.maximumDiscount,
    required this.validFrom,
    required this.validUntil,
    required this.usageLimit,
    required this.usageCount,
    required this.perUserLimit,
    required this.isActive,
  });

  final int id;
  final String code;
  final CouponDiscountType discountType;
  final double value;
  final double minimumOrderAmount;
  final double? maximumDiscount;
  final DateTime validFrom;
  final DateTime validUntil;
  final int? usageLimit;
  final int usageCount;
  final int perUserLimit;
  final bool isActive;

  bool get hasReachedUsageLimit =>
      usageLimit != null && usageCount >= usageLimit!;

  /// A display-only interpretation of the last server snapshot. Checkout
  /// remains responsible for authoritatively accepting or rejecting a coupon.
  CouponDisplayStatus displayStatusAt(DateTime nowUtc) {
    final now = nowUtc.toUtc();
    if (!isActive) return CouponDisplayStatus.inactive;
    if (validUntil.toUtc().isBefore(now) ||
        validUntil.toUtc().isAtSameMomentAs(now)) {
      return CouponDisplayStatus.expired;
    }
    if (validFrom.toUtc().isAfter(now)) return CouponDisplayStatus.scheduled;
    if (hasReachedUsageLimit) return CouponDisplayStatus.usageLimitReached;
    return CouponDisplayStatus.available;
  }
}

enum CouponDiscountType { percentage, fixed }

extension CouponDiscountTypeWire on CouponDiscountType {
  String get wireName => switch (this) {
    CouponDiscountType.percentage => 'Percentage',
    CouponDiscountType.fixed => 'Fixed',
  };

  String get label => switch (this) {
    CouponDiscountType.percentage => 'Percentage',
    CouponDiscountType.fixed => 'Fixed amount',
  };
}

CouponDiscountType couponDiscountTypeFromWire(String value) {
  return switch (value.trim().toLowerCase()) {
    'percentage' => CouponDiscountType.percentage,
    'fixed' => CouponDiscountType.fixed,
    _ => throw FormatException('Coupon returned an unsupported discount type.'),
  };
}

enum CouponDisplayStatus {
  available,
  inactive,
  scheduled,
  expired,
  usageLimitReached,
}

extension CouponDisplayStatusLabel on CouponDisplayStatus {
  String get label => switch (this) {
    CouponDisplayStatus.available => 'Available',
    CouponDisplayStatus.inactive => 'Inactive',
    CouponDisplayStatus.scheduled => 'Scheduled',
    CouponDisplayStatus.expired => 'Expired',
    CouponDisplayStatus.usageLimitReached => 'Limit reached',
  };
}

/// The complete create/update payload accepted by the commerce operations API.
class CouponDraft {
  const CouponDraft({
    required this.code,
    required this.discountType,
    required this.value,
    required this.minimumOrderAmount,
    required this.maximumDiscount,
    required this.validFrom,
    required this.validUntil,
    required this.usageLimit,
    required this.perUserLimit,
    required this.isActive,
  });

  final String code;
  final CouponDiscountType discountType;
  final double value;
  final double minimumOrderAmount;
  final double? maximumDiscount;
  final DateTime validFrom;
  final DateTime validUntil;
  final int? usageLimit;
  final int perUserLimit;
  final bool isActive;

  factory CouponDraft.fromCoupon(AdminCoupon coupon) => CouponDraft(
    code: coupon.code,
    discountType: coupon.discountType,
    value: coupon.value,
    minimumOrderAmount: coupon.minimumOrderAmount,
    maximumDiscount: coupon.maximumDiscount,
    validFrom: coupon.validFrom,
    validUntil: coupon.validUntil,
    usageLimit: coupon.usageLimit,
    perUserLimit: coupon.perUserLimit,
    isActive: coupon.isActive,
  );
}
