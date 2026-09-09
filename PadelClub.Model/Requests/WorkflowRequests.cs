using System;
using System.Collections.Generic;

namespace PadelClub.Model.Requests;

public sealed record InventoryAdjustmentRequest(int QuantityChange, string Reason);
public sealed record CouponRequest(string Code, string DiscountType, decimal Value, decimal MinimumOrderAmount, decimal? MaximumDiscount, DateTime ValidFrom, DateTime ValidUntil, int? UsageLimit, int PerUserLimit, bool IsActive);
public sealed record ReturnLineRequest(int OrderItemId, int Quantity);
public sealed record ReturnCreateRequest(int OrderId, string Reason, List<ReturnLineRequest> Items);
public sealed record ReturnResolutionRequest(bool Approve, string? AdminNotes);
public sealed record PlayerProfileRequest(string SkillLevel, string PreferredSide, int CityId, string Bio, string Availability, bool IsDiscoverable);
public sealed record PartnerInviteRequest(string Message);
public sealed record PartnerInviteResponse(bool Accept);
public sealed record MatchResultRequest(string Score, int WinnerTeamId);
public sealed record NotificationPreferenceRequest(bool InAppEnabled, bool EmailEnabled, bool PushEnabled);
public sealed record NotificationPreferenceResponse(bool InAppEnabled, bool EmailEnabled, bool PushEnabled);
public sealed record PushDeviceRequest(string InstallationId, string Platform);
public sealed record TournamentTeamRegistration(int PartnerUserId);
public sealed record TournamentRegistrationResponse(bool Accept);
