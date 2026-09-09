# Working-tree source index

Generated from the files on disk, including uncommitted changes. This lexical inventory supports navigation; it does not prove runtime reachability or passing tests.

Indexed 623 source, test, build and script files. Generated build/cache directories are excluded. Migration files are included.

## Controllers and declared actions

Routes without a prefix inherit `[Route("[controller]")]` from BaseController. Inherited GET/GET-by-ID and CRUD actions still exist when they are not redeclared below. Check both class and method policies and ownership checks. This is not a replacement for generated Swagger.

### BaseController

[PadelClub.WebAPI/Controllers/BaseController.cs](../../PadelClub.WebAPI/Controllers/BaseController.cs)

```csharp
12: [Route("[controller]")]
13: [Authorize]
14: public class BaseController<T, TSearch> : ControllerBase where T : class where TSearch : BaseSearchObject, new()
17: public BaseController(IService<T, TSearch> service)
21: [HttpGet("")]
22: public virtual async Task<PagedResult<T>> Get([FromQuery]TSearch? search)
27: [HttpGet("{id}")]
28: public virtual async Task<T?> GetById(int id)
```

### BaseCRUDController

[PadelClub.WebAPI/Controllers/BaseCRUDController.cs](../../PadelClub.WebAPI/Controllers/BaseCRUDController.cs)

```csharp
11: public class BaseCRUDController<T, TSearch, TInsert, TUpdate>
12: : BaseController<T, TSearch> where T : class where TSearch : BaseSearchObject, new() where TInsert : class where TUpdate : class
15: public BaseCRUDController(ICRUDService<T, TSearch, TInsert, TUpdate> service) : base(service)
20: [HttpPost]
21: public virtual async Task<ActionResult<T>> Create([FromBody] TInsert request)
34: return Conflict("A record with the same unique value already exists.");
38: [HttpPut("{id:int}")]
39: public virtual async Task<ActionResult<T?>> Update(int id, [FromBody] TUpdate request)
57: return Conflict("A record with the same unique value already exists.");
62: [HttpDelete("{id}")]
63: public virtual async Task<ActionResult<bool>> Delete(int id)
68: protected async Task<ActionResult<T?>> ActivateAsyncMethod(int id)
86: return Conflict("A record with the same unique value already exists.");
94: protected async Task<ActionResult<T?>> DeactivateAsyncMethod(int id)
112: return Conflict("A record with the same unique value already exists.");
```

### ClubReviewsController

[PadelClub.WebAPI/Controllers/ClubReviewsController.cs](../../PadelClub.WebAPI/Controllers/ClubReviewsController.cs)

```csharp
10: public class ClubReviewsController : BaseController<ClubReviewResponse, ClubReviewSearchObject>
14: public ClubReviewsController(IClubReviewService service) : base(service)
19: [HttpGet("mine")]
20: public async Task<ActionResult<ClubReviewResponse>> Mine()
26: [HttpPut("mine")]
27: public async Task<ActionResult<ClubReviewResponse>> SaveMine([FromBody] ClubReviewRequest request)
```

### CommerceOperationsController

[PadelClub.WebAPI/Controllers/CommerceOperationsController.cs](../../PadelClub.WebAPI/Controllers/CommerceOperationsController.cs)

```csharp
16: [Route("Commerce")]
17: [Authorize]
18: public sealed class CommerceOperationsController(PadelClubContext db, IProviderRefundOperationService refundOperations, INotificationService notifications) : ControllerBase
20: [HttpPost("inventory/{productId:int}/adjust")]
21: [Authorize(Policy = "AdminOnly")]
22: public async Task<IActionResult> AdjustInventory(int productId, InventoryAdjustmentRequest request, CancellationToken ct)
35: [HttpGet("inventory/{productId:int}/history")]
36: [Authorize(Policy = "AdminOnly")]
37: public async Task<ActionResult<object>> InventoryHistory(int productId, CancellationToken ct) => Ok(await db.InventoryMovements.AsNoTracking().Where(x => x.ProductId == productId)
40: [HttpPost("coupons")]
41: [Authorize(Policy = "AdminOnly")]
42: public async Task<ActionResult<object>> CreateCoupon(CouponRequest request, CancellationToken ct)
53: [HttpPut("coupons/{id:int}")]
54: [Authorize(Policy = "AdminOnly")]
55: public async Task<IActionResult> UpdateCoupon(int id, CouponRequest request, CancellationToken ct)
66: [HttpGet("coupons")]
67: [Authorize(Policy = "AdminOnly")]
68: public async Task<ActionResult<object>> Coupons(CancellationToken ct) => Ok(await db.Coupons.AsNoTracking().OrderByDescending(x => x.ValidUntil).Take(500)
71: [HttpPost("returns")]
72: public async Task<ActionResult<object>> RequestReturn(ReturnCreateRequest request, CancellationToken ct)
196: [HttpGet("returns/eligible-orders/mine")]
197: public async Task<ActionResult<IReadOnlyList<EligibleReturnOrderResponse>>> EligibleReturnOrders(CancellationToken ct)
282: [HttpGet("returns/mine")]
283: public async Task<ActionResult<object>> MyReturns(CancellationToken ct) => Ok(await db.ReturnRequests.AsNoTracking().Where(x => x.UserId == CurrentUserId()).OrderByDescending(x => x.CreatedAt)
286: [HttpGet("returns")]
287: [Authorize(Policy = "AdminOnly")]
288: public async Task<ActionResult<object>> Returns([FromQuery] string? status, CancellationToken ct)
294: [HttpPut("returns/{id:int}/resolve")]
295: [Authorize(Policy = "AdminOnly")]
296: public async Task<IActionResult> ResolveReturn(int id, ReturnResolutionRequest request, CancellationToken ct)
456: public sealed record InventoryAdjustmentRequest(int QuantityChange, string Reason);
457: public sealed record CouponRequest(string Code, string DiscountType, decimal Value, decimal MinimumOrderAmount, decimal? MaximumDiscount, DateTime ValidFrom, DateTime ValidUntil, int? UsageLimit, int PerUserLimit, bool IsActive);
458: public sealed record ReturnLineRequest(int OrderItemId, int Quantity);
459: public sealed record ReturnCreateRequest(int OrderId, string Reason, List<ReturnLineRequest> Items);
460: public sealed record ReturnResolutionRequest(bool Approve, string? AdminNotes);
```

### CourtsController

[PadelClub.WebAPI/Controllers/CourtsController.cs](../../PadelClub.WebAPI/Controllers/CourtsController.cs)

```csharp
11: public class CourtsController : BaseCRUDController<CourtResponse, CourtSearchObject, CourtInsertRequest, CourtUpdateRequest>
13: public CourtsController(ICourtService service) : base(service)
17: [HttpPost]
18: [Authorize(Policy = "AdminOnly")]
19: public override Task<ActionResult<CourtResponse>> Create([FromBody] CourtInsertRequest request) => base.Create(request);
21: [HttpPut("{id:int}")]
22: [Authorize(Policy = "AdminOnly")]
23: public override Task<ActionResult<CourtResponse?>> Update(int id, [FromBody] CourtUpdateRequest request) => base.Update(id, request);
25: [HttpDelete("{id:int}")]
26: [Authorize(Policy = "AdminOnly")]
27: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
```

### DiscoveryController

[PadelClub.WebAPI/Controllers/DiscoveryController.cs](../../PadelClub.WebAPI/Controllers/DiscoveryController.cs)

```csharp
10: [Route("[controller]")]
11: [Authorize]
12: public class DiscoveryController : ControllerBase
16: public DiscoveryController(PadelClubContext context)
21: [HttpGet("matches")]
22: public async Task<List<MatchSummaryResponse>> Matches([FromQuery] string? query)
55: [HttpGet("rankings")]
56: public async Task<List<PlayerRankingResponse>> Rankings([FromQuery] string? query)
```

### MatchParticipantsController

[PadelClub.WebAPI/Controllers/MatchParticipantsController.cs](../../PadelClub.WebAPI/Controllers/MatchParticipantsController.cs)

```csharp
10: [Authorize(Policy = "AdminOnly")]
11: public class MatchParticipantsController : BaseCRUDController<MatchParticipantResponse, MatchParticipantSearchObject, MatchParticipantInsertRequest, MatchParticipantUpdateRequest>
13: public MatchParticipantsController(IMatchParticipantService service) : base(service)
```

### MembershipsController

[PadelClub.WebAPI/Controllers/MembershipsController.cs](../../PadelClub.WebAPI/Controllers/MembershipsController.cs)

```csharp
14: public class MembershipsController : BaseCRUDController<MembershipResponse, MembershipSearchObject, MembershipInsertRequest, MembershipUpdateRequest>
19: public MembershipsController(IMembershipService service, PadelClubContext db, INotificationService notifications) : base(service)
25: [HttpGet, Authorize(Policy = "AdminOnly")]
26: public override Task<PagedResult<MembershipResponse>> Get([FromQuery] MembershipSearchObject? search) => base.Get(search);
27: [HttpGet("{id:int}"), Authorize(Policy = "AdminOnly")]
28: public override Task<MembershipResponse?> GetById(int id) => base.GetById(id);
29: [HttpPost, Authorize(Policy = "AdminOnly")]
30: public override Task<ActionResult<MembershipResponse>> Create([FromBody] MembershipInsertRequest request) => base.Create(request);
31: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
32: public override Task<ActionResult<MembershipResponse?>> Update(int id, [FromBody] MembershipUpdateRequest request) => base.Update(id, request);
33: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
34: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
36: [HttpGet("mine")]
37: public Task<PagedResult<MembershipResponse>> Mine([FromQuery] MembershipSearchObject? search)
44: [HttpPut("{id:int}/cancel-at-period-end")]
45: public async Task<IActionResult> CancelAtPeriodEnd(int id, CancellationToken ct)
56: [HttpPut("{id:int}/auto-renew")]
57: public async Task<IActionResult> AutoRenew(int id, [FromBody] AutoRenewRequest request, CancellationToken ct)
69: [HttpPut("{id:int}/status")]
70: [Authorize(Policy = "AdminOnly")]
71: public async Task<IActionResult> ChangeStatus(int id, [FromBody] MembershipStatusRequest request, CancellationToken ct)
87: [HttpPost("{id:int}/renew")]
88: [Authorize(Policy = "AdminOnly")]
89: public async Task<IActionResult> Renew(int id, [FromBody] MembershipRenewRequest request, CancellationToken ct)
102: [HttpGet("{id:int}/history")]
103: public async Task<ActionResult<object>> History(int id, CancellationToken ct)
116: public sealed record AutoRenewRequest(bool Enabled);
117: public sealed record MembershipStatusRequest(string Status, string Notes);
118: public sealed record MembershipRenewRequest(int Months);
```

### NotificationsController

[PadelClub.WebAPI/Controllers/NotificationsController.cs](../../PadelClub.WebAPI/Controllers/NotificationsController.cs)

```csharp
12: [Authorize]
13: public class NotificationsController : BaseCRUDController<NotificationResponse, NotificationSearchObject, NotificationInsertRequest, NotificationUpdateRequest>
17: public NotificationsController(INotificationService service) : base(service)
22: [HttpGet]
23: [Authorize(Policy = "AdminOnly")]
24: public override Task<PagedResult<NotificationResponse>> Get([FromQuery] NotificationSearchObject? search)
27: [HttpGet("{id:int}")]
28: [Authorize(Policy = "AdminOnly")]
29: public override Task<NotificationResponse?> GetById(int id) => base.GetById(id);
31: [HttpPost]
32: [Authorize(Policy = "AdminOnly")]
33: public override Task<ActionResult<NotificationResponse>> Create([FromBody] NotificationInsertRequest request)
36: [HttpPut("{id:int}")]
37: [Authorize(Policy = "AdminOnly")]
38: public override Task<ActionResult<NotificationResponse?>> Update(int id, [FromBody] NotificationUpdateRequest request)
41: [HttpDelete("{id:int}")]
42: [Authorize(Policy = "AdminOnly")]
43: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
45: [HttpGet("mine")]
46: public Task<PagedResult<NotificationResponse>> Mine([FromQuery] NotificationSearchObject? search)
49: [HttpPut("{id:int}/read")]
50: public async Task<ActionResult<NotificationResponse>> MarkRead(int id)
56: [HttpPut("read-all")]
57: public async Task<ActionResult<int>> MarkAllRead()
```

### NotificationSettingsController

[PadelClub.WebAPI/Controllers/NotificationSettingsController.cs](../../PadelClub.WebAPI/Controllers/NotificationSettingsController.cs)

```csharp
10: [Route("[controller]")]
11: [Authorize]
12: public sealed class NotificationSettingsController(PadelClubContext db) : ControllerBase
14: [HttpGet("mine")]
15: public async Task<ActionResult<NotificationPreferenceResponse>> Mine(CancellationToken cancellationToken)
22: [HttpPut("mine")]
23: public async Task<ActionResult<NotificationPreferenceResponse>> SaveMine(NotificationPreferenceRequest request, CancellationToken cancellationToken)
40: [HttpPost("devices")]
41: public async Task<IActionResult> RegisterDevice(PushDeviceRequest request, CancellationToken cancellationToken)
61: [HttpDelete("devices")]
62: public async Task<IActionResult> UnregisterDevice([FromQuery] string installationId, CancellationToken cancellationToken)
71: [HttpGet("deliveries")]
72: [Authorize(Policy = "AdminOnly")]
73: public async Task<ActionResult<object>> Deliveries([FromQuery] string? status, CancellationToken cancellationToken)
90: public sealed record NotificationPreferenceRequest(bool InAppEnabled, bool EmailEnabled, bool PushEnabled);
91: public sealed record NotificationPreferenceResponse(bool InAppEnabled, bool EmailEnabled, bool PushEnabled);
92: public sealed record PushDeviceRequest(string InstallationId, string Platform);
```

### OperationsController

[PadelClub.WebAPI/Controllers/OperationsController.cs](../../PadelClub.WebAPI/Controllers/OperationsController.cs)

```csharp
13: [Route("Operations")]
14: [Authorize(Policy = "AdminOnly")]
15: public sealed class OperationsController(
20: [HttpGet("analytics")]
21: public async Task<ActionResult<object>> Analytics([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
48: [HttpGet("recommendations/evaluation")]
49: public async Task<ActionResult<RecommendationEvaluationResponse>> RecommendationEvaluation(
86: [HttpGet("recommendations/cohort-readiness")]
87: public async Task<ActionResult<RecommendationCohortReadinessResponse>> RecommendationCohortReadiness(
95: [HttpPost("recommendations/evaluation/runs")]
96: public async Task<ActionResult<RecommendationEvaluationRunResponse>> CreateRecommendationEvaluationRun(
114: [HttpGet("recommendations/evaluation/runs/latest")]
115: public async Task<ActionResult<RecommendationEvaluationRunResponse>> GetLatestRecommendationEvaluationRun(
122: [HttpGet("recommendations/evaluation/runs/{runId:guid}")]
123: public async Task<ActionResult<RecommendationEvaluationRunResponse>> GetRecommendationEvaluationRun(
131: [HttpGet("audit")]
132: public async Task<ActionResult<object>> Audit([FromQuery] int? userId, [FromQuery] string? method, [FromQuery] DateTime? from, CancellationToken ct)
```

### OrderItemsController

[PadelClub.WebAPI/Controllers/OrderItemsController.cs](../../PadelClub.WebAPI/Controllers/OrderItemsController.cs)

```csharp
10: [Authorize(Policy = "AdminOnly")]
11: public class OrderItemsController : BaseCRUDController<OrderItemResponse, OrderItemSearchObject, OrderItemInsertRequest, OrderItemUpdateRequest>
13: public OrderItemsController(IOrderItemService service) : base(service)
```

### OrdersController

[PadelClub.WebAPI/Controllers/OrdersController.cs](../../PadelClub.WebAPI/Controllers/OrdersController.cs)

```csharp
11: public class OrdersController : BaseCRUDController<OrderResponse, OrderSearchObject, OrderInsertRequest, OrderUpdateRequest>
13: public OrdersController(IOrderService service) : base(service)
17: [HttpGet]
18: [Authorize(Policy = "AdminOnly")]
19: public override Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> Get(
22: [HttpGet("{id:int}")]
23: [Authorize(Policy = "AdminOnly")]
24: public override Task<OrderResponse?> GetById(int id) => base.GetById(id);
26: [HttpPost]
27: [Authorize(Policy = "AdminOnly")]
28: public override Task<ActionResult<OrderResponse>> Create([FromBody] OrderInsertRequest request)
31: [HttpPut("{id:int}")]
32: [Authorize(Policy = "AdminOnly")]
33: public override Task<ActionResult<OrderResponse?>> Update(int id, [FromBody] OrderUpdateRequest request)
36: [HttpDelete("{id:int}")]
37: [Authorize(Policy = "AdminOnly")]
38: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
40: [HttpGet("mine")]
41: public Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> Mine(
49: [HttpPost("checkout")]
50: public async Task<ActionResult<OrderResponse>> Checkout([FromBody] CheckoutRequest request)
```

### PaymentsController

[PadelClub.WebAPI/Controllers/PaymentsController.cs](../../PadelClub.WebAPI/Controllers/PaymentsController.cs)

```csharp
12: public class PaymentsController : BaseCRUDController<PaymentResponse, PaymentSearchObject, PaymentInsertRequest, PaymentUpdateRequest>
14: public PaymentsController(IPaymentService service) : base(service)
18: [HttpGet]
19: [Authorize(Policy = "AdminOnly")]
20: public override Task<PagedResult<PaymentResponse>> Get([FromQuery] PaymentSearchObject? search) => base.Get(search);
22: [HttpGet("{id:int}")]
23: [Authorize(Policy = "AdminOnly")]
24: public override Task<PaymentResponse?> GetById(int id) => base.GetById(id);
26: [HttpPost, Authorize(Policy = "AdminOnly")]
27: public override Task<ActionResult<PaymentResponse>> Create([FromBody] PaymentInsertRequest request) => base.Create(request);
28: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
29: public override Task<ActionResult<PaymentResponse?>> Update(int id, [FromBody] PaymentUpdateRequest request) => base.Update(id, request);
30: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
31: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
33: [HttpGet("mine")]
34: public Task<PagedResult<PaymentResponse>> Mine([FromQuery] PaymentSearchObject? search)
```

### PlayerExperienceController

[PadelClub.WebAPI/Controllers/PlayerExperienceController.cs](../../PadelClub.WebAPI/Controllers/PlayerExperienceController.cs)

```csharp
14: [Route("[controller]")]
15: [Authorize(Policy = "VerifiedPlayer")]
16: public sealed class PlayerExperienceController(PadelClubContext db, INotificationService notifications, IBracketService brackets) : ControllerBase
21: [HttpGet("profile/mine")]
22: public async Task<ActionResult<object>> Profile(CancellationToken ct)
29: [HttpPut("profile/mine")]
30: public async Task<ActionResult<object>> SaveProfile(PlayerProfileRequest request, CancellationToken ct)
53: [HttpGet("partners")]
54: public async Task<ActionResult<object>> Partners([FromQuery] string? skillLevel, [FromQuery] string? city, [FromQuery] string? query, CancellationToken ct)
70: [HttpPost("partners/{recipientUserId:int}/invite")]
71: public async Task<ActionResult<object>> Invite(int recipientUserId, PartnerInviteRequest request, CancellationToken ct)
86: [HttpGet("invitations/mine")]
87: public async Task<ActionResult<object>> Invitations(CancellationToken ct)
94: [HttpPut("invitations/{id:int}/respond")]
95: public async Task<IActionResult> Respond(int id, PartnerInviteResponse request, CancellationToken ct)
107: [HttpGet("matches/mine")]
108: public async Task<ActionResult<object>> MatchHistory(CancellationToken ct)
118: [HttpPost("matches/{matchId:int}/result")]
119: public async Task<IActionResult> ReportResult(int matchId, MatchResultRequest request, CancellationToken ct)
137: [HttpPost("matches/{matchId:int}/confirm")]
138: public async Task<IActionResult> ConfirmResult(int matchId, CancellationToken ct)
171: public sealed record PlayerProfileRequest(string SkillLevel, string PreferredSide, string City, string Bio, string Availability, bool IsDiscoverable);
172: public sealed record PartnerInviteRequest(string Message);
173: public sealed record PartnerInviteResponse(bool Accept);
174: public sealed record MatchResultRequest(string Score, int WinnerTeamId);
```

### PrivacyController

[PadelClub.WebAPI/Controllers/PrivacyController.cs](../../PadelClub.WebAPI/Controllers/PrivacyController.cs)

```csharp
10: [Route("Privacy")]
11: [Authorize]
12: public sealed class PrivacyController(PadelClubContext db) : ControllerBase
14: [HttpGet("export")]
15: public async Task<ActionResult<object>> Export(CancellationToken ct)
66: [HttpPost("deletion")]
67: public async Task<ActionResult<object>> RequestDeletion(CancellationToken ct)
77: [HttpDelete("deletion")]
78: public async Task<IActionResult> CancelDeletion(CancellationToken ct)
85: [HttpGet("deletion")]
86: public async Task<ActionResult<object>> DeletionStatus(CancellationToken ct)
```

### ProductCategoriesController

[PadelClub.WebAPI/Controllers/ProductCategoriesController.cs](../../PadelClub.WebAPI/Controllers/ProductCategoriesController.cs)

```csharp
10: public class ProductCategoriesController : BaseCRUDController<ProductCategoryResponse, ProductCategorySearchObject, ProductCategoryInsertRequest, ProductCategoryUpdateRequest>
12: public ProductCategoriesController(IProductCategoryService service) : base(service)
15: [HttpPost, Authorize(Policy = "AdminOnly")]
16: public override Task<ActionResult<ProductCategoryResponse>> Create([FromBody] ProductCategoryInsertRequest request) => base.Create(request);
17: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
18: public override Task<ActionResult<ProductCategoryResponse?>> Update(int id, [FromBody] ProductCategoryUpdateRequest request) => base.Update(id, request);
19: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
20: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
```

### ProductController

[PadelClub.WebAPI/Controllers/ProductController.cs](../../PadelClub.WebAPI/Controllers/ProductController.cs)

```csharp
11: public class ProductController : BaseCRUDController<ProductResponse, ProductSearchObject, ProductInsertRequest, ProductUpdateRequest>
13: public ProductController(IProductService service) : base(service)
17: [HttpPost]
18: [Authorize(Policy = "AdminOnly")]
19: public override async Task<ActionResult<ProductResponse>> Create([FromBody] ProductInsertRequest request)
24: [HttpPut("{id}/activate")]
25: [Authorize(Policy = "AdminOnly")]
26: public async Task<ActionResult<ProductResponse?>> ActivateAsync(int id)
31: [HttpPut("{id}/deactivate")]
32: [Authorize(Policy = "AdminOnly")]
33: public async Task<ActionResult<ProductResponse?>> DeactivateAsync(int id)
38: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
39: public override Task<ActionResult<ProductResponse?>> Update(int id, [FromBody] ProductUpdateRequest request) => base.Update(id, request);
41: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
42: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
```

### ProductTypesController

[PadelClub.WebAPI/Controllers/ProductTypesController.cs](../../PadelClub.WebAPI/Controllers/ProductTypesController.cs)

```csharp
10: public class ProductTypesController : BaseCRUDController<ProductTypeResponse, ProductTypeSearchObject, ProductTypeInsertRequest, ProductTypeUpdateRequest>
12: public ProductTypesController(IProductTypeService service) : base(service)
15: [HttpPost, Authorize(Policy = "AdminOnly")]
16: public override Task<ActionResult<ProductTypeResponse>> Create([FromBody] ProductTypeInsertRequest request) => base.Create(request);
17: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
18: public override Task<ActionResult<ProductTypeResponse?>> Update(int id, [FromBody] ProductTypeUpdateRequest request) => base.Update(id, request);
19: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
20: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
```

### ProviderReadinessController

[PadelClub.WebAPI/Controllers/ProviderReadinessController.cs](../../PadelClub.WebAPI/Controllers/ProviderReadinessController.cs)

```csharp
19: [Route("Operations/provider-readiness")]
20: [Authorize(Policy = "AdminOnly")]
21: public sealed class ProviderReadinessController(
27: [HttpGet]
28: public ActionResult<ProviderReadinessResponse> Get() => Ok(new ProviderReadinessResponse(
```

### ProviderVerificationController

[PadelClub.WebAPI/Controllers/ProviderVerificationController.cs](../../PadelClub.WebAPI/Controllers/ProviderVerificationController.cs)

```csharp
16: [Route("Operations/provider-verification")]
17: [Authorize(Policy = "AdminOnly")]
18: public sealed class ProviderVerificationController(IProviderVerificationService verification) : ControllerBase
20: [HttpGet]
21: public Task<IReadOnlyList<ProviderVerificationAttemptResponse>> Recent(
24: [HttpPost("{provider}")]
25: public async Task<ActionResult<ProviderVerificationAttemptResponse>> Verify(
```

### RecommendationExperimentsController

[PadelClub.WebAPI/Controllers/RecommendationExperimentsController.cs](../../PadelClub.WebAPI/Controllers/RecommendationExperimentsController.cs)

```csharp
16: [Route("Operations/recommendations/experiments")]
17: [Authorize(Policy = "AdminOnly")]
18: public sealed class RecommendationExperimentsController(
21: [HttpPost]
22: public async Task<ActionResult<RecommendationExperimentResponse>> Create(
36: [HttpGet("{experimentId:guid}")]
37: public async Task<ActionResult<RecommendationExperimentResponse>> Get(
45: [HttpPost("{experimentId:guid}/start")]
46: public Task<ActionResult<RecommendationExperimentResponse>> Start(
51: [HttpPost("{experimentId:guid}/close")]
52: public Task<ActionResult<RecommendationExperimentResponse>> Close(
57: [HttpGet("{experimentId:guid}/impact")]
58: public async Task<ActionResult<RecommendationExperimentImpactResponse>> Impact(
66: [HttpPost("{experimentId:guid}/analysis-runs")]
67: public async Task<ActionResult<RecommendationExperimentAnalysisRunResponse>> CreateAnalysisRun(
77: [HttpGet("{experimentId:guid}/analysis-runs/latest")]
78: public async Task<ActionResult<RecommendationExperimentAnalysisRunResponse>> GetLatestAnalysisRun(
```

### RecommendationImpactController

[PadelClub.WebAPI/Controllers/RecommendationImpactController.cs](../../PadelClub.WebAPI/Controllers/RecommendationImpactController.cs)

```csharp
14: [Route("Operations/recommendations/impact")]
15: [Authorize(Policy = "AdminOnly")]
16: public sealed class RecommendationImpactController(
19: [HttpGet]
20: public async Task<ActionResult<RecommendationImpactResponse>> Get(
```

### RecommendationsController

[PadelClub.WebAPI/Controllers/RecommendationsController.cs](../../PadelClub.WebAPI/Controllers/RecommendationsController.cs)

```csharp
11: [Route("[controller]")]
12: [Authorize]
13: public sealed class RecommendationsController(
17: [HttpGet("products")]
18: public async Task<ActionResult<IReadOnlyList<ProductRecommendationResponse>>> Products(
35: [HttpPost("products/{exposureId:guid}/click")]
36: public async Task<IActionResult> ProductClick(
55: [HttpGet("analytics-consent")]
56: public Task<ActionResult<RecommendationAnalyticsConsentResponse>> AnalyticsConsent(
64: [HttpPut("analytics-consent")]
65: public async Task<ActionResult<RecommendationAnalyticsConsentResponse>> SetAnalyticsConsent(
```

### ReservationsController

[PadelClub.WebAPI/Controllers/ReservationsController.cs](../../PadelClub.WebAPI/Controllers/ReservationsController.cs)

```csharp
12: public class ReservationsController : BaseCRUDController<ReservationResponse, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
14: public ReservationsController(IReservationService service) : base(service)
18: [HttpGet]
19: [Authorize(Policy = "AdminOnly")]
20: public override Task<PadelClub.Model.Responses.PagedResult<ReservationResponse>> Get([FromQuery] ReservationSearchObject? search) => base.Get(search);
22: [HttpGet("availability")]
23: public async Task<ActionResult> GetAvailability([FromQuery] DateTime date)
28: [HttpGet("mine")]
29: public async Task<ActionResult> GetMine([FromQuery] ReservationSearchObject? search)
34: [HttpPost]
35: public override Task<ActionResult<ReservationResponse>> Create([FromBody] ReservationInsertRequest request)
43: [HttpPut("{id:int}")]
44: [Authorize(Policy = "AdminOnly")]
45: public override Task<ActionResult<ReservationResponse?>> Update(int id, [FromBody] ReservationUpdateRequest request) => base.Update(id, request);
47: [HttpDelete("{id:int}")]
48: [Authorize(Policy = "AdminOnly")]
49: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
51: [HttpPut("{id:int}/cancel")]
52: public async Task<ActionResult> Cancel(int id)
66: [HttpPost("recurring")]
67: public Task<List<ReservationResponse>> CreateRecurring([FromBody] RecurringReservationRequest request) => ((IReservationService)_crudService).CreateRecurringAsync(GetUserId(), request);
69: [HttpPost("waitlist")]
70: public Task<PadelClub.Model.Responses.WaitlistEntryResponse> JoinWaitlist([FromBody] WaitlistRequest request) => ((IReservationService)_crudService).JoinWaitlistAsync(GetUserId(), request);
72: [HttpGet("waitlist/mine")]
73: public Task<List<PadelClub.Model.Responses.WaitlistEntryResponse>> WaitlistMine() => ((IReservationService)_crudService).GetWaitlistAsync(GetUserId());
75: [HttpGet("credits/mine")]
76: public Task<List<PadelClub.Model.Responses.AccountCreditResponse>> CreditsMine() => ((IReservationService)_crudService).GetCreditsAsync(GetUserId());
78: [HttpPost("maintenance"), Authorize(Policy = "AdminOnly")]
79: public async Task<ActionResult<int>> AddMaintenance([FromBody] MaintenanceBlockRequest request) => Ok(await ((IReservationService)_crudService).AddMaintenanceBlockAsync(request));
81: [HttpPut("{id:int}/no-show"), Authorize(Policy = "AdminOnly")]
82: public async Task<IActionResult> MarkNoShow(int id) => await ((IReservationService)_crudService).MarkNoShowAsync(id) ? NoContent() : NotFound();
```

### RolesController

[PadelClub.WebAPI/Controllers/RolesController.cs](../../PadelClub.WebAPI/Controllers/RolesController.cs)

```csharp
11: [Authorize(Policy = "AdminOnly")]
12: public class RolesController : BaseCRUDController<RoleResponse, RoleSearchObject, RoleInsertRequest, RoleUpdateRequest>
14: public RolesController(IRoleService service) : base(service)
18: [HttpGet]
19: public override async Task<PagedResult<RoleResponse>> Get([FromQuery] RoleSearchObject? search)
24: [HttpGet("{id}")]
25: public override async Task<RoleResponse?> GetById(int id)
```

### StripePaymentsController

[PadelClub.WebAPI/Controllers/StripePaymentsController.cs](../../PadelClub.WebAPI/Controllers/StripePaymentsController.cs)

```csharp
15: [Route("StripePayments")]
16: [Authorize]
17: public sealed class StripePaymentsController(
22: [HttpPost("intent")]
23: public Task<StripePaymentResponse> CreateIntent(CreateStripePaymentRequest request, CancellationToken cancellationToken) =>
26: [HttpPost("{paymentId:int}/refund")]
27: [Authorize(Policy = "AdminOnly")]
28: public async Task<ActionResult<ProviderRefundOperationResponse>> Refund(int paymentId, StripeRefundRequest request, CancellationToken cancellationToken)
34: [HttpGet("refunds/{operationId:guid}")]
35: [Authorize(Policy = "AdminOnly")]
36: public async Task<ActionResult<ProviderRefundOperationResponse>> GetRefundOperation(Guid operationId, CancellationToken cancellationToken)
42: [HttpPost("webhook")]
43: [AllowAnonymous]
45: public async Task<IActionResult> Webhook(CancellationToken cancellationToken)
```

### TournamentController

[PadelClub.WebAPI/Controllers/TournamentController.cs](../../PadelClub.WebAPI/Controllers/TournamentController.cs)

```csharp
10: public class TournamentController : BaseCRUDController<TournamentResponse, TournamentSearchObject, TournamentInsertRequest, TournamentUpdateRequest>
12: public TournamentController(ITournamentService service) : base(service)
15: [HttpPost, Authorize(Policy = "AdminOnly")]
16: public override Task<ActionResult<TournamentResponse>> Create([FromBody] TournamentInsertRequest request) => base.Create(request);
17: [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
18: public override Task<ActionResult<TournamentResponse?>> Update(int id, [FromBody] TournamentUpdateRequest request) => base.Update(id, request);
19: [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
20: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
```

### TournamentLifecycleController

[PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs](../../PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs)

```csharp
13: [Route("Tournaments")]
14: [Authorize]
15: public sealed class TournamentLifecycleController(PadelClubContext db, IBracketService brackets, INotificationService notifications) : ControllerBase
23: [HttpGet("mine")]
24: [Authorize(Policy = "VerifiedPlayer")]
25: public async Task<ActionResult<object>> Mine(CancellationToken ct)
59: [HttpPost("{tournamentId:int}/register")]
60: [Authorize(Policy = "VerifiedPlayer")]
61: public async Task<IActionResult> Register(int tournamentId, TournamentTeamRegistration request, CancellationToken ct)
80: [HttpPut("{tournamentId:int}/registration/respond")]
81: [Authorize(Policy = "VerifiedPlayer")]
82: public async Task<IActionResult> Respond(int tournamentId, TournamentRegistrationResponse request, CancellationToken ct)
95: [HttpDelete("{tournamentId:int}/registration/mine")]
96: [Authorize(Policy = "VerifiedPlayer")]
97: public async Task<IActionResult> Withdraw(int tournamentId, CancellationToken ct)
110: [HttpPost("{tournamentId:int}/bracket/generate")]
111: [Authorize(Policy = "AdminOnly")]
112: public async Task<IActionResult> Generate(int tournamentId, CancellationToken ct)
119: [HttpGet("{tournamentId:int}/bracket")]
120: public async Task<ActionResult<object>> Bracket(int tournamentId, CancellationToken ct)
134: public sealed record TournamentTeamRegistration(int PartnerUserId);
135: public sealed record TournamentRegistrationResponse(bool Accept);
```

### TournamentParticipantsController

[PadelClub.WebAPI/Controllers/TournamentParticipantsController.cs](../../PadelClub.WebAPI/Controllers/TournamentParticipantsController.cs)

```csharp
10: [Authorize(Policy = "AdminOnly")]
11: public class TournamentParticipantsController : BaseCRUDController<TournamentParticipantResponse, TournamentParticipantSearchObject, TournamentParticipantInsertRequest, TournamentParticipantUpdateRequest>
13: public TournamentParticipantsController(ITournamentParticipantService service) : base(service)
```

### UsersController

[PadelClub.WebAPI/Controllers/UsersController.cs](../../PadelClub.WebAPI/Controllers/UsersController.cs)

```csharp
15: public class UsersController : BaseCRUDController<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
19: public UsersController(IUserService service, IAuthService authService) : base(service)
25: [HttpGet]
26: [Authorize(Policy = "AdminOnly")]
27: public override Task<PadelClub.Model.Responses.PagedResult<UserResponse>> Get([FromQuery] UserSearchObject? search) => base.Get(search);
29: [HttpGet("{id:int}")]
30: [Authorize(Policy = "AdminOnly")]
31: public override Task<UserResponse?> GetById(int id) => base.GetById(id);
33: [HttpPost]
34: [Authorize(Policy = "AdminOnly")]
35: public override Task<ActionResult<UserResponse>> Create([FromBody] UserInsertRequest request) => base.Create(request);
37: [HttpPut("{id:int}")]
38: [Authorize(Policy = "AdminOnly")]
39: public override Task<ActionResult<UserResponse?>> Update(int id, [FromBody] UserUpdateRequest request) => base.Update(id, request);
41: [HttpDelete("{id:int}")]
42: [Authorize(Policy = "AdminOnly")]
43: public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
45: [HttpPost("login")]
46: [AllowAnonymous]
48: public async Task<ActionResult<AuthResponse>> Login(UserLoginRequest request, CancellationToken cancellationToken)
58: [HttpPost("refresh")]
59: [AllowAnonymous]
61: public async Task<ActionResult<AuthResponse>> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken)
64: [HttpPost("logout")]
65: public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
71: [HttpPost("forgot-password")]
72: [AllowAnonymous]
74: public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken cancellationToken)
80: [HttpPost("reset-password")]
81: [AllowAnonymous]
83: public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
86: [HttpPost("request-email-verification")]
87: public async Task<IActionResult> RequestEmailVerification(CancellationToken cancellationToken)
94: [HttpPost("verify-email")]
95: [AllowAnonymous]
97: public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request, CancellationToken cancellationToken)
100: [HttpGet("me")]
101: public async Task<ActionResult<UserResponse>> GetMe()
110: [HttpPut("me")]
111: public async Task<ActionResult<UserResponse>> UpdateMe(UserSelfUpdateRequest request)
```

## Database entities and mapping

### Asset

[PadelClub.Services/Database/Asset.cs](../../PadelClub.Services/Database/Asset.cs)

```csharp
public class Asset
public int Id { get; set; }
public int ProductId { get; set; }
public string Base64Image { get; set; } = string.Empty;
public int DisplayOrder { get; set; } = 0;
public bool IsPrimary { get; set; } = false;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual Product Product { get; set; } = null!;
```

### AuditLog

[PadelClub.Services/Database/AuditLog.cs](../../PadelClub.Services/Database/AuditLog.cs)

```csharp
public class AuditLog
public long Id { get; set; }
public int? UserId { get; set; }
public string Method { get; set; } = string.Empty;
public string Path { get; set; } = string.Empty;
public int StatusCode { get; set; }
public string IpAddress { get; set; } = string.Empty;
public string CorrelationId { get; set; } = string.Empty;
public long DurationMs { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
```

### AuthToken

[PadelClub.Services/Database/AuthToken.cs](../../PadelClub.Services/Database/AuthToken.cs)

```csharp
public class AuthToken
public long Id { get; set; }
public int UserId { get; set; }
public string TokenHash { get; set; } = string.Empty;
public string Purpose { get; set; } = string.Empty;
public DateTime ExpiresAt { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? ConsumedAt { get; set; }
public DateTime? RevokedAt { get; set; }
public long? ReplacedByTokenId { get; set; }
public string? FamilyId { get; set; }
public virtual User User { get; set; } = null!;
```

### BookingLifecycle

[PadelClub.Services/Database/BookingLifecycle.cs](../../PadelClub.Services/Database/BookingLifecycle.cs)

```csharp
public class MaintenanceBlock
public int Id { get; set; }
public int? CourtId { get; set; }
public DateTime StartTimeUtc { get; set; }
public DateTime EndTimeUtc { get; set; }
public string Reason { get; set; } = string.Empty;
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public Court? Court { get; set; }
public class WaitlistEntry
public int Id { get; set; }
public int CourtId { get; set; }
public int UserId { get; set; }
public DateTime StartTimeUtc { get; set; }
public DateTime EndTimeUtc { get; set; }
public string Status { get; set; } = "Waiting";
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? PromotedAt { get; set; }
public Court Court { get; set; } = null!;
public User User { get; set; } = null!;
public class AccountCredit
public int Id { get; set; }
public int UserId { get; set; }
public int? ReservationId { get; set; }
public decimal Amount { get; set; }
public string Reason { get; set; } = string.Empty;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UsedAt { get; set; }
public User User { get; set; } = null!;
public Reservation? Reservation { get; set; }
```

### ClubReview

[PadelClub.Services/Database/ClubReview.cs](../../PadelClub.Services/Database/ClubReview.cs)

```csharp
public class ClubReview
public int Id { get; set; }
public int UserId { get; set; }
public int Rating { get; set; }
public string Comment { get; set; } = string.Empty;
public bool IsPublished { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual User User { get; set; } = null!;
```

### Coupon

[PadelClub.Services/Database/Coupon.cs](../../PadelClub.Services/Database/Coupon.cs)

```csharp
public class Coupon
public int Id { get; set; }
public string Code { get; set; } = string.Empty;
public string DiscountType { get; set; } = "Percentage";
public decimal Value { get; set; }
public decimal MinimumOrderAmount { get; set; }
public decimal? MaximumDiscount { get; set; }
public DateTime ValidFrom { get; set; }
public DateTime ValidUntil { get; set; }
public int? UsageLimit { get; set; }
public int UsageCount { get; set; }
public int PerUserLimit { get; set; } = 1;
public bool IsActive { get; set; } = true;
public ICollection<CouponRedemption> Redemptions { get; set; } = new List<CouponRedemption>();
public class CouponRedemption
public long Id { get; set; }
public int CouponId { get; set; }
public int UserId { get; set; }
public int OrderId { get; set; }
public decimal DiscountAmount { get; set; }
public DateTime RedeemedAt { get; set; } = DateTime.UtcNow;
public Coupon Coupon { get; set; } = null!;
```

### Court

[PadelClub.Services/Database/Court.cs](../../PadelClub.Services/Database/Court.cs)

```csharp
public class Court
public int Id { get; set; }
public string Name { get; set; } = string.Empty;
public string Description { get; set; } = string.Empty;
public bool IsIndoor { get; set; }
public bool IsActive { get; set; } = true;
public decimal HourlyRate { get; set; }
public int MaxPlayers { get; set; } = 4; // Standard padel court capacity
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
public virtual ICollection<MaintenanceBlock> MaintenanceBlocks { get; set; } = new List<MaintenanceBlock>();
public virtual ICollection<WaitlistEntry> WaitlistEntries { get; set; } = new List<WaitlistEntry>();
```

### InboxMessage

[PadelClub.Services/Database/InboxMessage.cs](../../PadelClub.Services/Database/InboxMessage.cs)

```csharp
public sealed class InboxMessage
public long Id { get; set; }
public string Consumer { get; set; } = string.Empty;
public Guid EventId { get; set; }
public string MessageType { get; set; } = string.Empty;
public DateTime ReceivedAtUtc { get; set; } = DateTime.UtcNow;
```

### InventoryMovement

[PadelClub.Services/Database/InventoryMovement.cs](../../PadelClub.Services/Database/InventoryMovement.cs)

```csharp
public class InventoryMovement
public long Id { get; set; }
public int ProductId { get; set; }
public int QuantityChange { get; set; }
public int BalanceAfter { get; set; }
public string Reason { get; set; } = string.Empty;
public string ReferenceType { get; set; } = string.Empty;
public int? ReferenceId { get; set; }
public int? ActorUserId { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public Product Product { get; set; } = null!;
```

### Match

[PadelClub.Services/Database/Match.cs](../../PadelClub.Services/Database/Match.cs)

```csharp
public class Match
public int Id { get; set; }
public int TournamentId { get; set; }
public int CourtId { get; set; }
public DateTime ScheduledTime { get; set; }
public DateTime? ActualStartTime { get; set; }
public DateTime? ActualEndTime { get; set; }
public string Status { get; set; } = "Scheduled"; // Scheduled, InProgress, Completed, Cancelled
public int? WinnerTeamId { get; set; }
public string? Score { get; set; }
public string? Notes { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public string ResultStatus { get; set; } = "None";
public int? ReportedByUserId { get; set; }
public int? ProposedWinnerTeamId { get; set; }
public string? ProposedScore { get; set; }
public DateTime? ResultReportedAt { get; set; }
public DateTime? ResultConfirmedAt { get; set; }
public int? TeamOneRatingChange { get; set; }
public int? TeamTwoRatingChange { get; set; }
public int? BracketRound { get; set; }
public int? BracketPosition { get; set; }
public int? NextMatchId { get; set; }
public int? NextMatchTeamNumber { get; set; }
public bool IsBye { get; set; }
public Match? NextMatch { get; set; }
public ICollection<Match> PreviousMatches { get; set; } = new List<Match>();
public virtual Tournament Tournament { get; set; } = null!;
public virtual Court Court { get; set; } = null!;
public virtual ICollection<MatchParticipant> Participants { get; set; } = new List<MatchParticipant>();
```

### MatchParticipant

[PadelClub.Services/Database/MatchParticipant.cs](../../PadelClub.Services/Database/MatchParticipant.cs)

```csharp
public class MatchParticipant
public int Id { get; set; }
public int MatchId { get; set; }
public int UserId { get; set; }
public int TeamNumber { get; set; } // 1 or 2
public string Role { get; set; } = "Player"; // Player, Captain
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public virtual Match Match { get; set; } = null!;
public virtual User User { get; set; } = null!;
```

### Membership

[PadelClub.Services/Database/Membership.cs](../../PadelClub.Services/Database/Membership.cs)

```csharp
public class Membership
public int Id { get; set; }
public int UserId { get; set; }
public string MembershipType { get; set; } = string.Empty; // Basic, Premium, VIP
public DateTime StartDate { get; set; }
public DateTime EndDate { get; set; }
public decimal Price { get; set; }
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public string Status { get; set; } = "Active";
public bool AutoRenew { get; set; }
public bool CancelAtPeriodEnd { get; set; }
public DateTime? SuspendedAt { get; set; }
public DateTime? CancelledAt { get; set; }
public virtual User User { get; set; } = null!;
public virtual Payment? Payment { get; set; }
public virtual ICollection<MembershipEvent> Events { get; set; } = new List<MembershipEvent>();
```

### MembershipEvent

[PadelClub.Services/Database/MembershipEvent.cs](../../PadelClub.Services/Database/MembershipEvent.cs)

```csharp
public class MembershipEvent
public long Id { get; set; }
public int MembershipId { get; set; }
public string EventType { get; set; } = string.Empty;
public string Notes { get; set; } = string.Empty;
public int? ActorUserId { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public Membership Membership { get; set; } = null!;
```

### Notification

[PadelClub.Services/Database/Notification.cs](../../PadelClub.Services/Database/Notification.cs)

```csharp
public class Notification
public int Id { get; set; }
public string Title { get; set; } = string.Empty;
public string Message { get; set; } = string.Empty;
public string Type { get; set; } = "System";
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ICollection<NotificationRecipient> Recipients { get; set; } = new List<NotificationRecipient>();
public virtual ICollection<NotificationDelivery> Deliveries { get; set; } = new List<NotificationDelivery>();
```

### NotificationDelivery

[PadelClub.Services/Database/NotificationDelivery.cs](../../PadelClub.Services/Database/NotificationDelivery.cs)

```csharp
public class NotificationDelivery
public long Id { get; set; }
public int NotificationId { get; set; }
public int UserId { get; set; }
public string Channel { get; set; } = string.Empty;
public string Status { get; set; } = "Pending";
public int AttemptCount { get; set; }
public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;
public DateTime? SentAt { get; set; }
public string? ProviderMessageId { get; set; }
public string? LastError { get; set; }
public Notification Notification { get; set; } = null!;
public User User { get; set; } = null!;
```

### NotificationPreference

[PadelClub.Services/Database/NotificationPreference.cs](../../PadelClub.Services/Database/NotificationPreference.cs)

```csharp
public class NotificationPreference
public int Id { get; set; }
public int UserId { get; set; }
public bool InAppEnabled { get; set; } = true;
public bool EmailEnabled { get; set; } = true;
public bool PushEnabled { get; set; } = true;
public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
public User User { get; set; } = null!;
```

### NotificationRecipient

[PadelClub.Services/Database/NotificationRecipient.cs](../../PadelClub.Services/Database/NotificationRecipient.cs)

```csharp
public class NotificationRecipient
public int Id { get; set; }
public int NotificationId { get; set; }
public int UserId { get; set; }
public bool IsRead { get; set; }
public DateTime? ReadAt { get; set; }
public virtual Notification Notification { get; set; } = null!;
public virtual User User { get; set; } = null!;
```

### Order

[PadelClub.Services/Database/Order.cs](../../PadelClub.Services/Database/Order.cs)

```csharp
public class Order
public int Id { get; set; }
public int UserId { get; set; }
public string OrderNumber { get; set; } = string.Empty;
public decimal TotalAmount { get; set; }
public string Status { get; set; } = "Pending"; // Pending, Processing, Shipped, Delivered, Cancelled
public string RecipientName { get; set; } = string.Empty;
public string PhoneNumber { get; set; } = string.Empty;
public string ShippingAddress { get; set; } = string.Empty;
public string City { get; set; } = string.Empty;
public string PostalCode { get; set; } = string.Empty;
public string? Notes { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual User User { get; set; } = null!;
public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
public virtual Payment? Payment { get; set; }
public decimal SubtotalAmount { get; set; }
public decimal DiscountAmount { get; set; }
public int? CouponId { get; set; }
public string? CouponCode { get; set; }
public DateTime? DeliveredAt { get; set; }
public bool IsSeededForDemo { get; set; }
public OrderOrigin Origin { get; set; } = OrderOrigin.UnverifiedLegacy;
public virtual ICollection<ReturnRequest> ReturnRequests { get; set; } = new List<ReturnRequest>();
```

### OrderItem

[PadelClub.Services/Database/OrderItem.cs](../../PadelClub.Services/Database/OrderItem.cs)

```csharp
public class OrderItem
public int Id { get; set; }
public int OrderId { get; set; }
public int ProductId { get; set; }
public int Quantity { get; set; }
public decimal UnitPrice { get; set; }
public decimal TotalPrice { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public virtual Order Order { get; set; } = null!;
public virtual Product Product { get; set; } = null!;
```

### OrderOrigin

[PadelClub.Services/Database/OrderOrigin.cs](../../PadelClub.Services/Database/OrderOrigin.cs)

```csharp
public enum OrderOrigin
```

### OutboxMessage

[PadelClub.Services/Database/OutboxMessage.cs](../../PadelClub.Services/Database/OutboxMessage.cs)

```csharp
public sealed class OutboxMessage
public Guid Id { get; set; } = Guid.NewGuid();
public string Type { get; set; } = string.Empty;
public string Payload { get; set; } = string.Empty;
public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? PublishedAtUtc { get; set; }
public int AttemptCount { get; set; }
public DateTime NextAttemptAtUtc { get; set; } = DateTime.UtcNow;
public string? LastError { get; set; }
public Guid? LeaseId { get; set; }
public DateTime? LeaseExpiresAtUtc { get; set; }
```

### PartnerInvitation

[PadelClub.Services/Database/PartnerInvitation.cs](../../PadelClub.Services/Database/PartnerInvitation.cs)

```csharp
public class PartnerInvitation
public int Id { get; set; }
public int SenderUserId { get; set; }
public int RecipientUserId { get; set; }
public string Message { get; set; } = string.Empty;
public string Status { get; set; } = "Pending";
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? RespondedAt { get; set; }
public User Sender { get; set; } = null!;
public User Recipient { get; set; } = null!;
```

### Payment

[PadelClub.Services/Database/Payment.cs](../../PadelClub.Services/Database/Payment.cs)

```csharp
public class Payment
public int Id { get; set; }
public int UserId { get; set; }
public string PaymentType { get; set; } = string.Empty; // Reservation, Membership, Product
public int? ReservationId { get; set; }
public int? MembershipId { get; set; }
public int? OrderId { get; set; }
public decimal Amount { get; set; }
public string PaymentMethod { get; set; } = string.Empty; // CreditCard, Cash, BankTransfer
public string Status { get; set; } = "Pending"; // Pending, Completed, Failed, Refunded
public string? TransactionId { get; set; }
public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public string Provider { get; set; } = "Manual";
public string Currency { get; set; } = "bam";
public string? IdempotencyKey { get; set; }
public decimal RefundedAmount { get; set; }
public string? ReceiptUrl { get; set; }
public string? FailureMessage { get; set; }
public DateTime? ReconciledAt { get; set; }
public virtual User User { get; set; } = null!;
public virtual Reservation? Reservation { get; set; }
public virtual Membership? Membership { get; set; }
public virtual Order? Order { get; set; }
public virtual ICollection<ProviderRefundOperation> ProviderRefundOperations { get; set; } = new List<ProviderRefundOperation>();
```

### PlayerProfile

[PadelClub.Services/Database/PlayerProfile.cs](../../PadelClub.Services/Database/PlayerProfile.cs)

```csharp
public class PlayerProfile
public int Id { get; set; }
public int UserId { get; set; }
public string SkillLevel { get; set; } = "Beginner";
public string PreferredSide { get; set; } = "Either";
public string City { get; set; } = string.Empty;
public string Bio { get; set; } = string.Empty;
public string Availability { get; set; } = string.Empty;
public bool IsDiscoverable { get; set; } = true;
public int Rating { get; set; } = 1000;
public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
public User User { get; set; } = null!;
```

### PrivacyRequest

[PadelClub.Services/Database/PrivacyRequest.cs](../../PadelClub.Services/Database/PrivacyRequest.cs)

```csharp
public class PrivacyRequest
public long Id { get; set; }
public int UserId { get; set; }
public string RequestType { get; set; } = "Deletion";
public string Status { get; set; } = "Scheduled";
public DateTime RequestedAt { get; set; } = DateTime.UtcNow;
public DateTime ScheduledFor { get; set; }
public DateTime? CompletedAt { get; set; }
public DateTime? CancelledAt { get; set; }
public User User { get; set; } = null!;
```

### Product

[PadelClub.Services/Database/Product.cs](../../PadelClub.Services/Database/Product.cs)

```csharp
public class Product
public int Id { get; set; }
public string Name { get; set; } = string.Empty;
public string Description { get; set; } = string.Empty;
public decimal Price { get; set; }
public int StockQuantity { get; set; }
public int ProductCategoryId { get; set; }
public int ProductTypeId { get; set; }
public string? ImageUrl { get; set; }
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ProductCategory ProductCategory { get; set; } = null!;
public virtual ProductType ProductType { get; set; } = null!;
public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
public virtual ICollection<Asset> Assets { get; set; } = new List<Asset>();
public string ProductState { get; set; } = string.Empty;
public virtual ICollection<InventoryMovement> InventoryMovements { get; set; } = new List<InventoryMovement>();
```

### ProductCategory

[PadelClub.Services/Database/ProductCategory.cs](../../PadelClub.Services/Database/ProductCategory.cs)

```csharp
public class ProductCategory
public int Id { get; set; }
public string Name { get; set; } = string.Empty;
public string? Description { get; set; }
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ICollection<Product> Products { get; set; } = new List<Product>();
```

### ProductType

[PadelClub.Services/Database/ProductType.cs](../../PadelClub.Services/Database/ProductType.cs)

```csharp
public class ProductType
public int Id { get; set; }
public string Name { get; set; } = string.Empty;
public string? Description { get; set; }
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ICollection<Product> Products { get; set; } = new List<Product>();
```

### ProviderRefundOperation

[PadelClub.Services/Database/ProviderRefundOperation.cs](../../PadelClub.Services/Database/ProviderRefundOperation.cs)

```csharp
public sealed class ProviderRefundOperation
public Guid Id { get; set; } = Guid.NewGuid();
public int PaymentId { get; set; }
public int? ReturnRequestId { get; set; }
public int RequestedByUserId { get; set; }
public string Provider { get; set; } = string.Empty;
public string Currency { get; set; } = string.Empty;
public string PaymentIntentId { get; set; } = string.Empty;
public decimal Amount { get; set; }
public decimal ExpectedRefundedAmount { get; set; }
public string Reason { get; set; } = string.Empty;
public string IdempotencyKey { get; set; } = string.Empty;
public string Status { get; set; } = "Pending";
public string? ProviderRefundId { get; set; }
public int AttemptCount { get; set; }
public DateTime NextAttemptAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? LastAttemptAtUtc { get; set; }
public string? LastError { get; set; }
public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? ProviderAcceptedAtUtc { get; set; }
public DateTime? CompletedAtUtc { get; set; }
public Guid? LeaseId { get; set; }
public DateTime? LeaseExpiresAtUtc { get; set; }
public Payment Payment { get; set; } = null!;
public ReturnRequest? ReturnRequest { get; set; }
public User RequestedByUser { get; set; } = null!;
```

### ProviderVerificationAttempt

[PadelClub.Services/Database/ProviderVerificationAttempt.cs](../../PadelClub.Services/Database/ProviderVerificationAttempt.cs)

```csharp
public sealed class ProviderVerificationAttempt
public long Id { get; set; }
public Guid CorrelationId { get; set; } = Guid.NewGuid();
public int RequestedByUserId { get; set; }
public string Provider { get; set; } = string.Empty;
public string VerificationKind { get; set; } = string.Empty;
public string Status { get; set; } = ProviderVerificationAttemptStatuses.Started;
public string OutcomeCategory { get; set; } = ProviderVerificationOutcomeCategories.Started;
public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? CompletedAtUtc { get; set; }
public User RequestedByUser { get; set; } = null!;
public static class ProviderVerificationAttemptStatuses
public const string Started = "Started";
public const string Succeeded = "Succeeded";
public const string Failed = "Failed";
public static class ProviderVerificationOutcomeCategories
public const string Started = "Started";
public const string StripeTestReadAccepted = "StripeTestReadAccepted";
public const string SmtpAccepted = "SmtpAccepted";
public const string FirebaseAccepted = "FirebaseAccepted";
public const string ProviderRejected = "ProviderRejected";
public const string TransportFailure = "TransportFailure";
public const string UnexpectedFailure = "UnexpectedFailure";
```

### PushDevice

[PadelClub.Services/Database/PushDevice.cs](../../PadelClub.Services/Database/PushDevice.cs)

```csharp
public class PushDevice
public int Id { get; set; }
public int UserId { get; set; }
public string InstallationId { get; set; } = string.Empty;
public string Platform { get; set; } = string.Empty;
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
public User User { get; set; } = null!;
```

### RecommendationAnalyticsConsent

[PadelClub.Services/Database/RecommendationAnalyticsConsent.cs](../../PadelClub.Services/Database/RecommendationAnalyticsConsent.cs)

```csharp
public sealed class RecommendationAnalyticsConsent
public int UserId { get; set; }
public DateTime? GrantedAtUtc { get; set; }
public DateTime? RevokedAtUtc { get; set; }
public string PolicyVersion { get; set; } = string.Empty;
public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
public User User { get; set; } = null!;
public bool IsActive => GrantedAtUtc is not null && RevokedAtUtc is null;
```

### RecommendationEvaluationRun

[PadelClub.Services/Database/RecommendationEvaluationRun.cs](../../PadelClub.Services/Database/RecommendationEvaluationRun.cs)

```csharp
public sealed class RecommendationEvaluationRun
public long Id { get; set; }
public Guid RunId { get; set; } = Guid.NewGuid();
public int ExecutedByUserId { get; set; }
public DateTime ExecutedAtUtc { get; set; } = DateTime.UtcNow;
public string EvidenceSource { get; set; } = "Operational";
public string EvidenceTier { get; set; } = "Unavailable";
public string Protocol { get; set; } = string.Empty;
public string AlgorithmVersion { get; set; } = string.Empty;
public string ConfigurationSha256 { get; set; } = string.Empty;
public string InputFingerprintSha256 { get; set; } = string.Empty;
public DateTime CutoffUtc { get; set; }
public DateTime EndUtc { get; set; }
public int K { get; set; }
public int ReturnMaturityDays { get; set; }
public int EligibleDeliveredOrders { get; set; }
public int TrainingSignals { get; set; }
public int HoldoutSignals { get; set; }
public int CandidateProducts { get; set; }
public int EvaluatedUsers { get; set; }
public string ReportJson { get; set; } = string.Empty;
public User ExecutedByUser { get; set; } = null!;
```

### RecommendationExperiment

[PadelClub.Services/Database/RecommendationExperiment.cs](../../PadelClub.Services/Database/RecommendationExperiment.cs)

```csharp
public sealed class RecommendationExperiment
public Guid Id { get; set; } = Guid.NewGuid();
public string ExperimentKey { get; set; } = string.Empty;
public string Status { get; set; } = "Draft";
public int CreatedByUserId { get; set; }
public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? StartedAtUtc { get; set; }
public DateTime? ClosedAtUtc { get; set; }
public string Protocol { get; set; } = string.Empty;
public string TreatmentAlgorithmVersion { get; set; } = string.Empty;
public string ControlAlgorithmVersion { get; set; } = string.Empty;
public string TreatmentStrategy { get; set; } = string.Empty;
public string ControlStrategy { get; set; } = string.Empty;
public int TreatmentAllocationPercent { get; set; }
public int RecommendationLimit { get; set; }
public int AttributionWindowDays { get; set; }
public int ReturnMaturityDays { get; set; }
public string ConfigurationSha256 { get; set; } = string.Empty;
public User CreatedByUser { get; set; } = null!;
public ICollection<RecommendationExperimentAssignment> Assignments { get; set; } =
public ICollection<RecommendationExperimentAnalysisRun> AnalysisRuns { get; set; } =
```

### RecommendationExperimentAnalysisRun

[PadelClub.Services/Database/RecommendationExperimentAnalysisRun.cs](../../PadelClub.Services/Database/RecommendationExperimentAnalysisRun.cs)

```csharp
public sealed class RecommendationExperimentAnalysisRun
public long Id { get; set; }
public Guid RunId { get; set; } = Guid.NewGuid();
public Guid ExperimentId { get; set; }
public int ExecutedByUserId { get; set; }
public DateTime ExecutedAtUtc { get; set; } = DateTime.UtcNow;
public string EvidenceTier { get; set; } = "Collecting";
public string Protocol { get; set; } = string.Empty;
public string ConfigurationSha256 { get; set; } = string.Empty;
public string InputFingerprintSha256 { get; set; } = string.Empty;
public string ReportJson { get; set; } = string.Empty;
public RecommendationExperiment Experiment { get; set; } = null!;
public User ExecutedByUser { get; set; } = null!;
```

### RecommendationExperimentAssignment

[PadelClub.Services/Database/RecommendationExperimentAssignment.cs](../../PadelClub.Services/Database/RecommendationExperimentAssignment.cs)

```csharp
public sealed class RecommendationExperimentAssignment
public Guid Id { get; set; } = Guid.NewGuid();
public Guid ExperimentId { get; set; }
public int UserId { get; set; }
public RecommendationExperimentVariant Variant { get; set; }
public DateTime AssignedAtUtc { get; set; } = DateTime.UtcNow;
public RecommendationExperiment Experiment { get; set; } = null!;
public User User { get; set; } = null!;
public ICollection<RecommendationExposure> Exposures { get; set; } =
```

### RecommendationExperimentVariant

[PadelClub.Services/Database/RecommendationExperimentVariant.cs](../../PadelClub.Services/Database/RecommendationExperimentVariant.cs)

```csharp
public enum RecommendationExperimentVariant
```

### RecommendationExposure

[PadelClub.Services/Database/RecommendationExposure.cs](../../PadelClub.Services/Database/RecommendationExposure.cs)

```csharp
public sealed class RecommendationExposure
public Guid Id { get; set; } = Guid.NewGuid();
public int UserId { get; set; }
public int ProductId { get; set; }
public RecommendationTelemetrySource TelemetrySource { get; set; } =
public string AlgorithmVersion { get; set; } = string.Empty;
public string Strategy { get; set; } = string.Empty;
public int Rank { get; set; }
public DateTime ServedAtUtc { get; set; } = DateTime.UtcNow;
public DateTime? ClickedAtUtc { get; set; }
public int? PurchasedOrderId { get; set; }
public DateTime? PurchasedAtUtc { get; set; }
public Guid? ExperimentAssignmentId { get; set; }
public User User { get; set; } = null!;
public Product Product { get; set; } = null!;
public Order? PurchasedOrder { get; set; }
public RecommendationExperimentAssignment? ExperimentAssignment { get; set; }
```

### RecommendationTelemetrySource

[PadelClub.Services/Database/RecommendationTelemetrySource.cs](../../PadelClub.Services/Database/RecommendationTelemetrySource.cs)

```csharp
public enum RecommendationTelemetrySource
```

### Reservation

[PadelClub.Services/Database/Reservation.cs](../../PadelClub.Services/Database/Reservation.cs)

```csharp
public class Reservation
public int Id { get; set; }
public int CourtId { get; set; }
public int UserId { get; set; }
public DateTime StartTime { get; set; }
public DateTime EndTime { get; set; }
public decimal TotalPrice { get; set; }
public string Status { get; set; } = "Pending"; // Pending, Confirmed, Cancelled, Completed
public string? Notes { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public Guid? SeriesId { get; set; }
public DateTime? CancelledAt { get; set; }
public bool IsNoShow { get; set; }
public virtual Court Court { get; set; } = null!;
public virtual User User { get; set; } = null!;
public virtual Payment? Payment { get; set; }
public virtual ICollection<AccountCredit> Credits { get; set; } = new List<AccountCredit>();
```

### ReturnRequest

[PadelClub.Services/Database/ReturnRequest.cs](../../PadelClub.Services/Database/ReturnRequest.cs)

```csharp
public class ReturnRequest
public int Id { get; set; }
public int OrderId { get; set; }
public int UserId { get; set; }
public string Reason { get; set; } = string.Empty;
public string Status { get; set; } = "Requested";
public decimal RefundAmount { get; set; }
public string? AdminNotes { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? ResolvedAt { get; set; }
public Order Order { get; set; } = null!;
public ICollection<ReturnRequestItem> Items { get; set; } = new List<ReturnRequestItem>();
public ICollection<ProviderRefundOperation> ProviderRefundOperations { get; set; } = new List<ProviderRefundOperation>();
public class ReturnRequestItem
public int Id { get; set; }
public int ReturnRequestId { get; set; }
public int OrderItemId { get; set; }
public int Quantity { get; set; }
public decimal RefundAmount { get; set; }
public bool Restocked { get; set; }
public ReturnRequest ReturnRequest { get; set; } = null!;
public OrderItem OrderItem { get; set; } = null!;
```

### Role

[PadelClub.Services/Database/Role.cs](../../PadelClub.Services/Database/Role.cs)

```csharp
public class Role
public int Id { get; set; }
public string Name { get; set; } = null!;
public string? Description { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public bool IsActive { get; set; } = true;
public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
```

### StripeWebhookEvent

[PadelClub.Services/Database/StripeWebhookEvent.cs](../../PadelClub.Services/Database/StripeWebhookEvent.cs)

```csharp
public class StripeWebhookEvent
public long Id { get; set; }
public string StripeEventId { get; set; } = string.Empty;
public string EventType { get; set; } = string.Empty;
public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
public DateTime? ProcessedAt { get; set; }
public string? ProcessingError { get; set; }
```

### Tournament

[PadelClub.Services/Database/Tournament.cs](../../PadelClub.Services/Database/Tournament.cs)

```csharp
public class Tournament
public int Id { get; set; }
public string Name { get; set; } = string.Empty;
public string Description { get; set; } = string.Empty;
public DateTime StartDate { get; set; }
public DateTime EndDate { get; set; }
public DateTime RegistrationDeadline { get; set; }
public int MaxParticipants { get; set; }
public decimal EntryFee { get; set; }
public string Status { get; set; } = "Upcoming"; // Upcoming, Ongoing, Completed, Cancelled
public string? PrizeInfo { get; set; }
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public virtual ICollection<Match> Matches { get; set; } = new List<Match>();
public virtual ICollection<TournamentParticipant> Participants { get; set; } = new List<TournamentParticipant>();
```

### TournamentParticipant

[PadelClub.Services/Database/TournamentParticipant.cs](../../PadelClub.Services/Database/TournamentParticipant.cs)

```csharp
public class TournamentParticipant
public int Id { get; set; }
public int TournamentId { get; set; }
public int UserId { get; set; }
public string Status { get; set; } = "Registered"; // Registered, Confirmed, Withdrawn
public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;
public DateTime? ConfirmedAt { get; set; }
public int? TeamNumber { get; set; }
public int? Seed { get; set; }
public virtual Tournament Tournament { get; set; } = null!;
public virtual User User { get; set; } = null!;
```

### User

[PadelClub.Services/Database/User.cs](../../PadelClub.Services/Database/User.cs)

```csharp
public class User
public int Id { get; set; }
public string Username { get; set; } = string.Empty;
public string Email { get; set; } = string.Empty;
public string FirstName { get; set; } = string.Empty;
public string LastName { get; set; } = string.Empty;
public string PasswordHash { get; set; } = string.Empty;
public string PasswordSalt { get; set; } = string.Empty;
public string? PhoneNumber { get; set; }
public bool IsActive { get; set; } = true;
public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
public DateTime? UpdatedAt { get; set; }
public DateTime? EmailVerifiedAt { get; set; }
public virtual ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
public virtual ICollection<Membership> Memberships { get; set; } = new List<Membership>();
public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();
public virtual ICollection<ProviderRefundOperation> RequestedProviderRefundOperations { get; set; } = new List<ProviderRefundOperation>();
public virtual ICollection<Order> Orders { get; set; } = new List<Order>();
public virtual ICollection<TournamentParticipant> TournamentParticipants { get; set; } = new List<TournamentParticipant>();
public virtual ICollection<MatchParticipant> MatchParticipants { get; set; } = new List<MatchParticipant>();
public virtual ICollection<NotificationRecipient> NotificationRecipients { get; set; } = new List<NotificationRecipient>();
public virtual ICollection<ClubReview> ClubReviews { get; set; } = new List<ClubReview>();
public virtual ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
public virtual ICollection<AuthToken> AuthTokens { get; set; } = new List<AuthToken>();
public virtual ICollection<WaitlistEntry> WaitlistEntries { get; set; } = new List<WaitlistEntry>();
public virtual ICollection<AccountCredit> AccountCredits { get; set; } = new List<AccountCredit>();
public virtual NotificationPreference? NotificationPreference { get; set; }
public virtual RecommendationAnalyticsConsent? RecommendationAnalyticsConsent { get; set; }
public virtual ICollection<RecommendationExperimentAssignment> RecommendationExperimentAssignments { get; set; } = new List<RecommendationExperimentAssignment>();
public virtual ICollection<PushDevice> PushDevices { get; set; } = new List<PushDevice>();
public virtual ICollection<NotificationDelivery> NotificationDeliveries { get; set; } = new List<NotificationDelivery>();
public virtual PlayerProfile? PlayerProfile { get; set; }
public virtual ICollection<PartnerInvitation> SentPartnerInvitations { get; set; } = new List<PartnerInvitation>();
public virtual ICollection<PartnerInvitation> ReceivedPartnerInvitations { get; set; } = new List<PartnerInvitation>();
public virtual ICollection<PrivacyRequest> PrivacyRequests { get; set; } = new List<PrivacyRequest>();
```

### UserRole

[PadelClub.Services/Database/UserRole.cs](../../PadelClub.Services/Database/UserRole.cs)

```csharp
public class UserRole
public int Id { get; set; }
public int UserId { get; set; }
public virtual User User { get; set; } = null!;
public int RoleId { get; set; }
public virtual Role Role { get; set; } = null!;
public DateTime DateAssigned { get; set; } = DateTime.UtcNow;
```

## EF relationships, keys and delete rules

[PadelClub.Services/Database/PadelClubContext.cs](../../PadelClub.Services/Database/PadelClubContext.cs)

```csharp
213: modelBuilder.Entity<RecommendationEvaluationRun>(entity =>
222: entity.HasIndex(x => x.RunId).IsUnique();
223: entity.HasIndex(x => x.ExecutedAtUtc);
224: entity.HasIndex(x => new { x.EvidenceSource, x.ExecutedAtUtc });
225: entity.HasOne(x => x.ExecutedByUser)
226: .WithMany()
227: .HasForeignKey(x => x.ExecutedByUserId)
228: .OnDelete(DeleteBehavior.Restrict);
234: modelBuilder.Entity<OutboxMessage>(entity =>
239: entity.HasIndex(x => new { x.PublishedAtUtc, x.NextAttemptAtUtc });
240: entity.HasIndex(x => new { x.PublishedAtUtc, x.NextAttemptAtUtc, x.LeaseExpiresAtUtc });
241: entity.HasIndex(x => x.OccurredAtUtc);
247: modelBuilder.Entity<InboxMessage>(entity =>
252: entity.HasIndex(x => new { x.Consumer, x.EventId }).IsUnique();
253: entity.HasIndex(x => x.ReceivedAtUtc);
259: modelBuilder.Entity<RecommendationExposure>(entity =>
265: entity.HasIndex(x => new { x.UserId, x.ServedAtUtc });
266: entity.HasIndex(x => new { x.ProductId, x.ServedAtUtc });
267: entity.HasIndex(x => new { x.TelemetrySource, x.ServedAtUtc });
268: entity.HasIndex(x => new { x.ExperimentAssignmentId, x.ServedAtUtc });
269: entity.HasOne(x => x.User)
270: .WithMany()
271: .HasForeignKey(x => x.UserId)
272: .OnDelete(DeleteBehavior.Restrict);
273: entity.HasOne(x => x.Product)
274: .WithMany()
275: .HasForeignKey(x => x.ProductId)
276: .OnDelete(DeleteBehavior.Restrict);
277: entity.HasOne(x => x.PurchasedOrder)
278: .WithMany()
279: .HasForeignKey(x => x.PurchasedOrderId)
280: .OnDelete(DeleteBehavior.NoAction);
281: entity.HasOne(x => x.ExperimentAssignment)
282: .WithMany(x => x.Exposures)
283: .HasForeignKey(x => x.ExperimentAssignmentId)
284: .OnDelete(DeleteBehavior.NoAction);
290: modelBuilder.Entity<RecommendationAnalyticsConsent>(entity =>
292: entity.HasKey(x => x.UserId);
295: entity.HasOne(x => x.User)
296: .WithOne(x => x.RecommendationAnalyticsConsent)
297: .HasForeignKey<RecommendationAnalyticsConsent>(x => x.UserId)
298: .OnDelete(DeleteBehavior.NoAction);
301: modelBuilder.Entity<RecommendationExperiment>(entity =>
303: entity.HasKey(x => x.Id);
312: entity.HasIndex(x => x.ExperimentKey).IsUnique();
313: entity.HasIndex(x => x.Status)
314: .HasFilter("[Status] = N'Running'")
315: .IsUnique();
316: entity.HasOne(x => x.CreatedByUser)
317: .WithMany()
318: .HasForeignKey(x => x.CreatedByUserId)
319: .OnDelete(DeleteBehavior.Restrict);
322: modelBuilder.Entity<RecommendationExperimentAssignment>(entity =>
324: entity.HasKey(x => x.Id);
325: entity.HasIndex(x => new { x.ExperimentId, x.UserId }).IsUnique();
326: entity.HasIndex(x => new { x.ExperimentId, x.Variant, x.AssignedAtUtc });
327: entity.HasOne(x => x.Experiment)
328: .WithMany(x => x.Assignments)
329: .HasForeignKey(x => x.ExperimentId)
330: .OnDelete(DeleteBehavior.NoAction);
331: entity.HasOne(x => x.User)
332: .WithMany(x => x.RecommendationExperimentAssignments)
333: .HasForeignKey(x => x.UserId)
334: .OnDelete(DeleteBehavior.NoAction);
337: modelBuilder.Entity<RecommendationExperimentAnalysisRun>(entity =>
339: entity.HasKey(x => x.Id);
345: entity.HasIndex(x => x.RunId).IsUnique();
346: entity.HasIndex(x => new { x.ExperimentId, x.ExecutedAtUtc });
347: entity.HasOne(x => x.Experiment)
348: .WithMany(x => x.AnalysisRuns)
349: .HasForeignKey(x => x.ExperimentId)
350: .OnDelete(DeleteBehavior.NoAction);
351: entity.HasOne(x => x.ExecutedByUser)
352: .WithMany()
353: .HasForeignKey(x => x.ExecutedByUserId)
354: .OnDelete(DeleteBehavior.Restrict);
360: modelBuilder.Entity<ProviderVerificationAttempt>(entity =>
366: entity.HasIndex(x => x.CorrelationId).IsUnique();
367: entity.HasIndex(x => new { x.Provider, x.StartedAtUtc });
368: entity.HasOne(x => x.RequestedByUser)
369: .WithMany()
370: .HasForeignKey(x => x.RequestedByUserId)
371: .OnDelete(DeleteBehavior.Restrict);
377: modelBuilder.Entity<PrivacyRequest>(entity =>
381: entity.HasIndex(x => new { x.UserId, x.Status });
382: entity.HasIndex(x => new { x.Status, x.ScheduledFor });
383: entity.HasOne(x => x.User).WithMany(x => x.PrivacyRequests).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
389: modelBuilder.Entity<InventoryMovement>(entity =>
393: entity.HasIndex(x => new { x.ProductId, x.CreatedAt });
394: entity.HasOne(x => x.Product).WithMany(x => x.InventoryMovements).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.NoAction);
396: modelBuilder.Entity<Coupon>(entity =>
403: entity.HasIndex(x => x.Code).IsUnique();
405: modelBuilder.Entity<CouponRedemption>(entity =>
408: entity.HasIndex(x => new { x.CouponId, x.UserId });
409: entity.HasIndex(x => x.OrderId).IsUnique();
410: entity.HasOne(x => x.Coupon).WithMany(x => x.Redemptions).HasForeignKey(x => x.CouponId).OnDelete(DeleteBehavior.NoAction);
412: modelBuilder.Entity<ReturnRequest>(entity =>
418: entity.HasIndex(x => new { x.UserId, x.Status });
419: entity.HasOne(x => x.Order).WithMany(x => x.ReturnRequests).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.NoAction);
421: modelBuilder.Entity<ReturnRequestItem>(entity =>
424: entity.HasIndex(x => new { x.ReturnRequestId, x.OrderItemId }).IsUnique();
425: entity.HasOne(x => x.ReturnRequest).WithMany(x => x.Items).HasForeignKey(x => x.ReturnRequestId).OnDelete(DeleteBehavior.Cascade);
426: entity.HasOne(x => x.OrderItem).WithMany().HasForeignKey(x => x.OrderItemId).OnDelete(DeleteBehavior.NoAction);
428: modelBuilder.Entity<AuditLog>(entity =>
434: entity.HasIndex(x => x.CreatedAt);
435: entity.HasIndex(x => x.UserId);
437: modelBuilder.Entity<Order>(entity =>
447: modelBuilder.Entity<TournamentParticipant>(entity =>
449: entity.HasIndex(x => new { x.TournamentId, x.TeamNumber });
451: modelBuilder.Entity<Match>(entity =>
453: entity.HasIndex(x => new { x.TournamentId, x.BracketRound, x.BracketPosition }).IsUnique()
454: .HasFilter("[BracketRound] IS NOT NULL AND [BracketPosition] IS NOT NULL");
455: entity.HasOne(x => x.NextMatch).WithMany(x => x.PreviousMatches).HasForeignKey(x => x.NextMatchId).OnDelete(DeleteBehavior.NoAction);
457: modelBuilder.Entity<Membership>(entity =>
460: entity.HasIndex(x => new { x.Status, x.EndDate });
462: modelBuilder.Entity<MembershipEvent>(entity =>
466: entity.HasIndex(x => new { x.MembershipId, x.CreatedAt });
467: entity.HasOne(x => x.Membership).WithMany(x => x.Events).HasForeignKey(x => x.MembershipId).OnDelete(DeleteBehavior.Cascade);
473: modelBuilder.Entity<PlayerProfile>(entity =>
480: entity.HasIndex(x => x.UserId).IsUnique();
481: entity.HasIndex(x => new { x.IsDiscoverable, x.SkillLevel, x.City });
482: entity.HasOne(x => x.User).WithOne(x => x.PlayerProfile)
483: .HasForeignKey<PlayerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
485: modelBuilder.Entity<PartnerInvitation>(entity =>
489: entity.HasIndex(x => new { x.SenderUserId, x.RecipientUserId, x.Status });
490: entity.HasOne(x => x.Sender).WithMany(x => x.SentPartnerInvitations).HasForeignKey(x => x.SenderUserId).OnDelete(DeleteBehavior.NoAction);
491: entity.HasOne(x => x.Recipient).WithMany(x => x.ReceivedPartnerInvitations).HasForeignKey(x => x.RecipientUserId).OnDelete(DeleteBehavior.NoAction);
493: modelBuilder.Entity<Match>(entity =>
502: modelBuilder.Entity<NotificationPreference>(entity =>
504: entity.HasIndex(x => x.UserId).IsUnique();
505: entity.HasOne(x => x.User).WithOne(x => x.NotificationPreference)
506: .HasForeignKey<NotificationPreference>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
508: modelBuilder.Entity<PushDevice>(entity =>
512: entity.HasIndex(x => x.InstallationId).IsUnique();
513: entity.HasIndex(x => new { x.UserId, x.IsActive });
514: entity.HasOne(x => x.User).WithMany(x => x.PushDevices).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
516: modelBuilder.Entity<NotificationDelivery>(entity =>
522: entity.HasIndex(x => new { x.NotificationId, x.UserId, x.Channel }).IsUnique();
523: entity.HasIndex(x => new { x.Status, x.NextAttemptAt });
524: entity.HasOne(x => x.Notification).WithMany(x => x.Deliveries).HasForeignKey(x => x.NotificationId).OnDelete(DeleteBehavior.Cascade);
525: entity.HasOne(x => x.User).WithMany(x => x.NotificationDeliveries).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
531: modelBuilder.Entity<Payment>(entity =>
539: entity.HasIndex(x => x.IdempotencyKey).IsUnique().HasFilter("[IdempotencyKey] IS NOT NULL");
541: modelBuilder.Entity<StripeWebhookEvent>(entity =>
546: entity.HasIndex(x => x.StripeEventId).IsUnique();
552: modelBuilder.Entity<ProviderRefundOperation>(entity =>
568: entity.HasIndex(x => x.IdempotencyKey).IsUnique();
569: entity.HasIndex(x => x.ReturnRequestId).IsUnique().HasFilter("[ReturnRequestId] IS NOT NULL");
570: entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.LeaseExpiresAtUtc });
571: entity.HasIndex(x => new { x.PaymentId, x.Status });
573: entity.HasOne(x => x.Payment)
574: .WithMany(x => x.ProviderRefundOperations)
575: .HasForeignKey(x => x.PaymentId)
576: .OnDelete(DeleteBehavior.Restrict);
577: entity.HasOne(x => x.ReturnRequest)
578: .WithMany(x => x.ProviderRefundOperations)
579: .HasForeignKey(x => x.ReturnRequestId)
580: .OnDelete(DeleteBehavior.Restrict);
581: entity.HasOne(x => x.RequestedByUser)
582: .WithMany(x => x.RequestedProviderRefundOperations)
583: .HasForeignKey(x => x.RequestedByUserId)
584: .OnDelete(DeleteBehavior.Restrict);
590: modelBuilder.Entity<MaintenanceBlock>(entity =>
593: entity.HasIndex(x => new { x.CourtId, x.StartTimeUtc, x.EndTimeUtc });
594: entity.HasOne(x => x.Court).WithMany(x => x.MaintenanceBlocks).HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Cascade);
596: modelBuilder.Entity<WaitlistEntry>(entity =>
599: entity.HasIndex(x => new { x.CourtId, x.StartTimeUtc, x.EndTimeUtc, x.Status });
600: entity.HasIndex(x => new { x.UserId, x.CourtId, x.StartTimeUtc, x.EndTimeUtc }).IsUnique();
601: entity.HasOne(x => x.Court).WithMany(x => x.WaitlistEntries).HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Restrict);
602: entity.HasOne(x => x.User).WithMany(x => x.WaitlistEntries).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
604: modelBuilder.Entity<AccountCredit>(entity =>
608: entity.HasOne(x => x.User).WithMany(x => x.AccountCredits).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
609: entity.HasOne(x => x.Reservation).WithMany(x => x.Credits).HasForeignKey(x => x.ReservationId).OnDelete(DeleteBehavior.SetNull);
611: modelBuilder.Entity<Reservation>().HasIndex(x => x.SeriesId);
616: modelBuilder.Entity<AuthToken>(entity =>
618: entity.ToTable("AuthTokens");
619: entity.HasKey(x => x.Id);
623: entity.HasIndex(x => x.TokenHash).IsUnique();
624: entity.HasIndex(x => new { x.UserId, x.Purpose, x.ExpiresAt });
625: entity.HasIndex(x => x.FamilyId);
626: entity.HasOne(x => x.User).WithMany(x => x.AuthTokens)
627: .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
633: modelBuilder.Entity<ClubReview>(entity =>
635: entity.ToTable("ClubReviews");
636: entity.HasKey(e => e.Id);
640: entity.HasOne(e => e.User).WithMany(e => e.ClubReviews)
641: .HasForeignKey(e => e.UserId).OnDelete(DeleteBehavior.Cascade);
642: entity.HasIndex(e => new { e.IsPublished, e.CreatedAt });
643: entity.ToTable(t => t.HasCheckConstraint("CK_ClubReviews_Rating", "[Rating] >= 1 AND [Rating] <= 5"));
649: modelBuilder.Entity<User>(entity =>
651: entity.ToTable("Users");
652: entity.HasKey(e => e.Id);
658: entity.HasIndex(e => e.Username)
659: .IsUnique();
665: entity.HasIndex(e => e.Email)
666: .IsUnique();
696: modelBuilder.Entity<Role>(entity =>
698: entity.ToTable("Roles");
699: entity.HasKey(e => e.Id);
714: entity.HasIndex(e => e.Name)
715: .IsUnique();
721: modelBuilder.Entity<UserRole>(entity =>
723: entity.ToTable("UserRoles");
724: entity.HasKey(e => e.Id);
729: entity.HasOne(e => e.User)
730: .WithMany(u => u.UserRoles)
731: .HasForeignKey(e => e.UserId)
732: .OnDelete(DeleteBehavior.Cascade);
734: entity.HasOne(e => e.Role)
735: .WithMany(r => r.UserRoles)
736: .HasForeignKey(e => e.RoleId)
737: .OnDelete(DeleteBehavior.Restrict);
739: entity.HasIndex(e => new { e.UserId, e.RoleId })
740: .IsUnique();
746: modelBuilder.Entity<Court>(entity =>
748: entity.ToTable("Courts");
749: entity.HasKey(e => e.Id);
767: entity.HasIndex(e => e.Name);
773: modelBuilder.Entity<Reservation>(entity =>
775: entity.ToTable("Reservations");
776: entity.HasKey(e => e.Id);
792: entity.HasOne(e => e.Court)
793: .WithMany(c => c.Reservations)
794: .HasForeignKey(e => e.CourtId)
795: .OnDelete(DeleteBehavior.Restrict);
797: entity.HasOne(e => e.User)
798: .WithMany(u => u.Reservations)
799: .HasForeignKey(e => e.UserId)
800: .OnDelete(DeleteBehavior.Restrict);
802: entity.HasIndex(e => new { e.CourtId, e.StartTime, e.EndTime });
803: entity.HasIndex(e => e.UserId);
804: entity.HasIndex(e => e.Status);
810: modelBuilder.Entity<Product>(entity =>
812: entity.ToTable("Products");
813: entity.HasKey(e => e.Id);
834: entity.HasOne(e => e.ProductCategory)
835: .WithMany(c => c.Products)
836: .HasForeignKey(e => e.ProductCategoryId)
837: .OnDelete(DeleteBehavior.Restrict);
839: entity.HasOne(e => e.ProductType)
840: .WithMany(t => t.Products)
841: .HasForeignKey(e => e.ProductTypeId)
842: .OnDelete(DeleteBehavior.Restrict);
844: entity.HasIndex(e => e.ProductCategoryId);
845: entity.HasIndex(e => e.ProductTypeId);
846: entity.HasIndex(e => e.Name);
852: modelBuilder.Entity<Membership>(entity =>
854: entity.ToTable("Memberships");
855: entity.HasKey(e => e.Id);
870: entity.HasOne(e => e.User)
871: .WithMany(u => u.Memberships)
872: .HasForeignKey(e => e.UserId)
873: .OnDelete(DeleteBehavior.Restrict);
875: entity.HasIndex(e => e.UserId);
876: entity.HasIndex(e => new { e.UserId, e.IsActive });
882: modelBuilder.Entity<Payment>(entity =>
884: entity.ToTable("Payments");
885: entity.HasKey(e => e.Id);
912: entity.HasOne(e => e.User)
913: .WithMany(u => u.Payments)
914: .HasForeignKey(e => e.UserId)
915: .OnDelete(DeleteBehavior.Restrict);
917: entity.HasOne(e => e.Reservation)
918: .WithOne(r => r.Payment)
919: .HasForeignKey<Payment>(e => e.ReservationId)
920: .OnDelete(DeleteBehavior.SetNull);
922: entity.HasOne(e => e.Membership)
923: .WithOne(m => m.Payment)
924: .HasForeignKey<Payment>(e => e.MembershipId)
925: .OnDelete(DeleteBehavior.SetNull);
927: entity.HasOne(e => e.Order)
928: .WithOne(o => o.Payment)
929: .HasForeignKey<Payment>(e => e.OrderId)
930: .OnDelete(DeleteBehavior.SetNull);
932: entity.HasIndex(e => e.UserId);
933: entity.HasIndex(e => e.Status);
934: entity.HasIndex(e => e.TransactionId);
940: modelBuilder.Entity<Tournament>(entity =>
942: entity.ToTable("Tournaments");
943: entity.HasKey(e => e.Id);
966: entity.HasIndex(e => e.Status);
967: entity.HasIndex(e => e.StartDate);
973: modelBuilder.Entity<Match>(entity =>
975: entity.ToTable("Matches");
976: entity.HasKey(e => e.Id);
992: entity.HasOne(e => e.Tournament)
993: .WithMany(t => t.Matches)
994: .HasForeignKey(e => e.TournamentId)
995: .OnDelete(DeleteBehavior.Restrict);
997: entity.HasOne(e => e.Court)
998: .WithMany()
999: .HasForeignKey(e => e.CourtId)
1000: .OnDelete(DeleteBehavior.Restrict);
1002: entity.HasIndex(e => e.TournamentId);
1003: entity.HasIndex(e => e.CourtId);
1004: entity.HasIndex(e => e.ScheduledTime);
1010: modelBuilder.Entity<MatchParticipant>(entity =>
1012: entity.ToTable("MatchParticipants");
1013: entity.HasKey(e => e.Id);
1023: entity.HasOne(e => e.Match)
1024: .WithMany(m => m.Participants)
1025: .HasForeignKey(e => e.MatchId)
1026: .OnDelete(DeleteBehavior.Cascade);
1028: entity.HasOne(e => e.User)
1029: .WithMany(u => u.MatchParticipants)
1030: .HasForeignKey(e => e.UserId)
1031: .OnDelete(DeleteBehavior.Restrict);
1033: entity.HasIndex(e => new { e.MatchId, e.UserId }).IsUnique();
1039: modelBuilder.Entity<TournamentParticipant>(entity =>
1041: entity.ToTable("TournamentParticipants");
1042: entity.HasKey(e => e.Id);
1052: entity.HasOne(e => e.Tournament)
1053: .WithMany(t => t.Participants)
1054: .HasForeignKey(e => e.TournamentId)
1055: .OnDelete(DeleteBehavior.Restrict);
1057: entity.HasOne(e => e.User)
1058: .WithMany(u => u.TournamentParticipants)
1059: .HasForeignKey(e => e.UserId)
1060: .OnDelete(DeleteBehavior.Restrict);
1062: entity.HasIndex(e => new { e.TournamentId, e.UserId }).IsUnique();
1068: modelBuilder.Entity<Order>(entity =>
1070: entity.ToTable("Orders");
1071: entity.HasKey(e => e.Id);
1117: entity.HasOne(e => e.User)
1118: .WithMany(u => u.Orders)
1119: .HasForeignKey(e => e.UserId)
1120: .OnDelete(DeleteBehavior.Restrict);
1122: entity.HasIndex(e => e.OrderNumber).IsUnique();
1123: entity.HasIndex(e => e.UserId);
1124: entity.HasIndex(e => e.Status);
1125: entity.HasIndex(e => new { e.Status, e.IsSeededForDemo, e.DeliveredAt });
1126: entity.HasIndex(e => new { e.Status, e.Origin, e.DeliveredAt });
1132: modelBuilder.Entity<OrderItem>(entity =>
1134: entity.ToTable("OrderItems");
1135: entity.HasKey(e => e.Id);
1146: entity.HasOne(e => e.Order)
1147: .WithMany(o => o.OrderItems)
1148: .HasForeignKey(e => e.OrderId)
1149: .OnDelete(DeleteBehavior.Cascade);
1151: entity.HasOne(e => e.Product)
1152: .WithMany(p => p.OrderItems)
1153: .HasForeignKey(e => e.ProductId)
1154: .OnDelete(DeleteBehavior.Restrict);
1156: entity.HasIndex(e => e.OrderId);
1162: modelBuilder.Entity<Asset>(entity =>
1164: entity.ToTable("Assets");
1165: entity.HasKey(e => e.Id);
1179: entity.HasOne(e => e.Product)
1180: .WithMany(p => p.Assets)
1181: .HasForeignKey(e => e.ProductId)
1182: .OnDelete(DeleteBehavior.Cascade);
1184: entity.HasIndex(e => e.ProductId);
1185: entity.HasIndex(e => new { e.ProductId, e.DisplayOrder });
1191: modelBuilder.Entity<ProductCategory>(entity =>
1193: entity.ToTable("ProductCategories");
1194: entity.HasKey(e => e.Id);
1209: entity.HasIndex(e => e.Name);
1215: modelBuilder.Entity<ProductType>(entity =>
1217: entity.ToTable("ProductTypes");
1218: entity.HasKey(e => e.Id);
1233: entity.HasIndex(e => e.Name);
1239: modelBuilder.Entity<Notification>(entity =>
1241: entity.ToTable("Notifications");
1242: entity.HasKey(e => e.Id);
1247: entity.HasIndex(e => e.Type);
1248: entity.HasIndex(e => e.CreatedAt);
1254: modelBuilder.Entity<NotificationRecipient>(entity =>
1256: entity.ToTable("NotificationRecipients");
1257: entity.HasKey(e => e.Id);
1259: entity.HasOne(e => e.Notification)
1260: .WithMany(n => n.Recipients)
1261: .HasForeignKey(e => e.NotificationId)
1262: .OnDelete(DeleteBehavior.Cascade);
1263: entity.HasOne(e => e.User)
1264: .WithMany(u => u.NotificationRecipients)
1265: .HasForeignKey(e => e.UserId)
1266: .OnDelete(DeleteBehavior.Cascade);
1267: entity.HasIndex(e => new { e.NotificationId, e.UserId }).IsUnique();
1268: entity.HasIndex(e => new { e.UserId, e.IsRead });
```

## UI files and feature groups

- [UI/padelclub_desktop/lib/core/di/injection.dart](../../UI/padelclub_desktop/lib/core/di/injection.dart)
- [UI/padelclub_desktop/lib/core/network/api_config.dart](../../UI/padelclub_desktop/lib/core/network/api_config.dart)
- [UI/padelclub_desktop/lib/core/theme/app_theme.dart](../../UI/padelclub_desktop/lib/core/theme/app_theme.dart)
- [UI/padelclub_desktop/lib/core/widgets/admin_components.dart](../../UI/padelclub_desktop/lib/core/widgets/admin_components.dart)
- [UI/padelclub_desktop/lib/dashboard_page.dart](../../UI/padelclub_desktop/lib/dashboard_page.dart)
- [UI/padelclub_desktop/lib/features/coupons/data/coupon_management_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/coupons/data/coupon_management_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/coupons/domain/entities/admin_coupon.dart](../../UI/padelclub_desktop/lib/features/coupons/domain/entities/admin_coupon.dart)
- [UI/padelclub_desktop/lib/features/coupons/presentation/providers/coupon_management_provider.dart](../../UI/padelclub_desktop/lib/features/coupons/presentation/providers/coupon_management_provider.dart)
- [UI/padelclub_desktop/lib/features/coupons/presentation/screens/coupon_management_screen.dart](../../UI/padelclub_desktop/lib/features/coupons/presentation/screens/coupon_management_screen.dart)
- [UI/padelclub_desktop/lib/features/courts/data/models/court_model.dart](../../UI/padelclub_desktop/lib/features/courts/data/models/court_model.dart)
- [UI/padelclub_desktop/lib/features/courts/domain/entities/court.dart](../../UI/padelclub_desktop/lib/features/courts/domain/entities/court.dart)
- [UI/padelclub_desktop/lib/features/courts/presentation/providers/court_provider.dart](../../UI/padelclub_desktop/lib/features/courts/presentation/providers/court_provider.dart)
- [UI/padelclub_desktop/lib/features/courts/presentation/screens/court_management_screen.dart](../../UI/padelclub_desktop/lib/features/courts/presentation/screens/court_management_screen.dart)
- [UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart](../../UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/models/inventory_movement_model.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/models/inventory_movement_model.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/entities/inventory_movement.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/entities/inventory_movement.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/repositories/inventory_operations_repository.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/repositories/inventory_operations_repository.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/adjust_inventory.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/adjust_inventory.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/get_inventory_history.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/get_inventory_history.dart)
- [UI/padelclub_desktop/lib/features/inventory_operations/presentation/providers/inventory_operations_provider.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/presentation/providers/inventory_operations_provider.dart)
- [UI/padelclub_desktop/lib/features/match_participants/data/datasources/match_participant_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/datasources/match_participant_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/match_participants/data/models/match_participant_model.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/models/match_participant_model.dart)
- [UI/padelclub_desktop/lib/features/match_participants/data/repositories/match_participant_repository_impl.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/repositories/match_participant_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/match_participants/domain/entities/match_participant.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/entities/match_participant.dart)
- [UI/padelclub_desktop/lib/features/match_participants/domain/repositories/match_participant_repository.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/repositories/match_participant_repository.dart)
- [UI/padelclub_desktop/lib/features/match_participants/domain/usecases/get_match_participants.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/usecases/get_match_participants.dart)
- [UI/padelclub_desktop/lib/features/match_participants/presentation/providers/match_participant_provider.dart](../../UI/padelclub_desktop/lib/features/match_participants/presentation/providers/match_participant_provider.dart)
- [UI/padelclub_desktop/lib/features/memberships/data/admin_membership_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/memberships/data/admin_membership_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/memberships/data/datasources/membership_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/memberships/data/datasources/membership_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/memberships/data/models/membership_event_model.dart](../../UI/padelclub_desktop/lib/features/memberships/data/models/membership_event_model.dart)
- [UI/padelclub_desktop/lib/features/memberships/data/models/membership_model.dart](../../UI/padelclub_desktop/lib/features/memberships/data/models/membership_model.dart)
- [UI/padelclub_desktop/lib/features/memberships/data/repositories/membership_repository_impl.dart](../../UI/padelclub_desktop/lib/features/memberships/data/repositories/membership_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership.dart)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_event.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_event.dart)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_page.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_page.dart)
- [UI/padelclub_desktop/lib/features/memberships/domain/repositories/membership_repository.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/repositories/membership_repository.dart)
- [UI/padelclub_desktop/lib/features/memberships/domain/usecases/get_memberships.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/usecases/get_memberships.dart)
- [UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_management_provider.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_management_provider.dart)
- [UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_provider.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_provider.dart)
- [UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_management_screen.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_management_screen.dart)
- [UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_self_service_screen.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_self_service_screen.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/data/models/notification_preferences_model.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/models/notification_preferences_model.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/data/repositories/notification_settings_repository_impl.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/repositories/notification_settings_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/entities/notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/entities/notification_preferences.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/repositories/notification_settings_repository.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/repositories/notification_settings_repository.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/get_notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/get_notification_preferences.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/save_notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/save_notification_preferences.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/presentation/providers/notification_settings_provider.dart](../../UI/padelclub_desktop/lib/features/notification_settings/presentation/providers/notification_settings_provider.dart)
- [UI/padelclub_desktop/lib/features/notification_settings/presentation/screens/notification_settings_screen.dart](../../UI/padelclub_desktop/lib/features/notification_settings/presentation/screens/notification_settings_screen.dart)
- [UI/padelclub_desktop/lib/features/notifications/data/models/club_notification_model.dart](../../UI/padelclub_desktop/lib/features/notifications/data/models/club_notification_model.dart)
- [UI/padelclub_desktop/lib/features/notifications/data/notification_delivery_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/notifications/data/notification_delivery_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/notifications/domain/entities/club_notification.dart](../../UI/padelclub_desktop/lib/features/notifications/domain/entities/club_notification.dart)
- [UI/padelclub_desktop/lib/features/notifications/domain/entities/notification_delivery.dart](../../UI/padelclub_desktop/lib/features/notifications/domain/entities/notification_delivery.dart)
- [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart)
- [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart)
- [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_delivery_diagnostics_screen.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_delivery_diagnostics_screen.dart)
- [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart)
- [UI/padelclub_desktop/lib/features/operations/data/audit_trail_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/operations/data/audit_trail_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/operations/data/provider_readiness_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/operations/data/provider_readiness_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/audit_log_entry.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/audit_log_entry.dart)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/audit_trail_filter.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/audit_trail_filter.dart)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/provider_readiness.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/provider_readiness.dart)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/audit_trail_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/audit_trail_provider.dart)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/operations_analytics_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/operations_analytics_provider.dart)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/provider_readiness_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/provider_readiness_provider.dart)
- [UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart)
- [UI/padelclub_desktop/lib/features/operations/presentation/screens/provider_readiness_screen.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/screens/provider_readiness_screen.dart)
- [UI/padelclub_desktop/lib/features/order_items/data/datasources/order_item_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/order_items/data/datasources/order_item_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/order_items/data/models/order_item_model.dart](../../UI/padelclub_desktop/lib/features/order_items/data/models/order_item_model.dart)
- [UI/padelclub_desktop/lib/features/order_items/data/repositories/order_item_repository_impl.dart](../../UI/padelclub_desktop/lib/features/order_items/data/repositories/order_item_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/order_items/domain/entities/order_item.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/entities/order_item.dart)
- [UI/padelclub_desktop/lib/features/order_items/domain/repositories/order_item_repository.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/repositories/order_item_repository.dart)
- [UI/padelclub_desktop/lib/features/order_items/domain/usecases/get_order_items.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/usecases/get_order_items.dart)
- [UI/padelclub_desktop/lib/features/order_items/presentation/providers/order_item_provider.dart](../../UI/padelclub_desktop/lib/features/order_items/presentation/providers/order_item_provider.dart)
- [UI/padelclub_desktop/lib/features/orders/data/datasources/order_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/orders/data/datasources/order_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/orders/data/models/order_model.dart](../../UI/padelclub_desktop/lib/features/orders/data/models/order_model.dart)
- [UI/padelclub_desktop/lib/features/orders/data/repositories/order_repository_impl.dart](../../UI/padelclub_desktop/lib/features/orders/data/repositories/order_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/orders/domain/entities/order.dart](../../UI/padelclub_desktop/lib/features/orders/domain/entities/order.dart)
- [UI/padelclub_desktop/lib/features/orders/domain/repositories/order_repository.dart](../../UI/padelclub_desktop/lib/features/orders/domain/repositories/order_repository.dart)
- [UI/padelclub_desktop/lib/features/orders/domain/usecases/get_orders.dart](../../UI/padelclub_desktop/lib/features/orders/domain/usecases/get_orders.dart)
- [UI/padelclub_desktop/lib/features/orders/presentation/providers/order_provider.dart](../../UI/padelclub_desktop/lib/features/orders/presentation/providers/order_provider.dart)
- [UI/padelclub_desktop/lib/features/orders/presentation/screens/order_management_screen.dart](../../UI/padelclub_desktop/lib/features/orders/presentation/screens/order_management_screen.dart)
- [UI/padelclub_desktop/lib/features/payment_history/data/payment_history_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/payment_history/data/payment_history_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/payment_history/domain/entities/payment_history_entry.dart](../../UI/padelclub_desktop/lib/features/payment_history/domain/entities/payment_history_entry.dart)
- [UI/padelclub_desktop/lib/features/payment_history/presentation/providers/payment_history_provider.dart](../../UI/padelclub_desktop/lib/features/payment_history/presentation/providers/payment_history_provider.dart)
- [UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart](../../UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart)
- [UI/padelclub_desktop/lib/features/payments/data/datasources/payment_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/payments/data/datasources/payment_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/payments/data/models/payment_model.dart](../../UI/padelclub_desktop/lib/features/payments/data/models/payment_model.dart)
- [UI/padelclub_desktop/lib/features/payments/data/repositories/payment_repository_impl.dart](../../UI/padelclub_desktop/lib/features/payments/data/repositories/payment_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/payments/domain/entities/payment.dart](../../UI/padelclub_desktop/lib/features/payments/domain/entities/payment.dart)
- [UI/padelclub_desktop/lib/features/payments/domain/repositories/payment_repository.dart](../../UI/padelclub_desktop/lib/features/payments/domain/repositories/payment_repository.dart)
- [UI/padelclub_desktop/lib/features/payments/domain/usecases/get_payments.dart](../../UI/padelclub_desktop/lib/features/payments/domain/usecases/get_payments.dart)
- [UI/padelclub_desktop/lib/features/payments/presentation/providers/payment_provider.dart](../../UI/padelclub_desktop/lib/features/payments/presentation/providers/payment_provider.dart)
- [UI/padelclub_desktop/lib/features/player_experience/presentation/providers/player_experience_provider.dart](../../UI/padelclub_desktop/lib/features/player_experience/presentation/providers/player_experience_provider.dart)
- [UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart](../../UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart)
- [UI/padelclub_desktop/lib/features/privacy/data/datasources/privacy_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/privacy/data/datasources/privacy_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/privacy/data/models/privacy_deletion_status_model.dart](../../UI/padelclub_desktop/lib/features/privacy/data/models/privacy_deletion_status_model.dart)
- [UI/padelclub_desktop/lib/features/privacy/data/repositories/privacy_repository_impl.dart](../../UI/padelclub_desktop/lib/features/privacy/data/repositories/privacy_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/entities/privacy_deletion_status.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/entities/privacy_deletion_status.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/repositories/privacy_repository.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/repositories/privacy_repository.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/cancel_account_deletion.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/cancel_account_deletion.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_account_deletion_status.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_account_deletion_status.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_privacy_export.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_privacy_export.dart)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/request_account_deletion.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/request_account_deletion.dart)
- [UI/padelclub_desktop/lib/features/privacy/presentation/providers/privacy_controls_provider.dart](../../UI/padelclub_desktop/lib/features/privacy/presentation/providers/privacy_controls_provider.dart)
- [UI/padelclub_desktop/lib/features/privacy/presentation/screens/privacy_controls_screen.dart](../../UI/padelclub_desktop/lib/features/privacy/presentation/screens/privacy_controls_screen.dart)
- [UI/padelclub_desktop/lib/features/product/data/datasources/product_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product/data/datasources/product_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/product/data/models/product_model.dart](../../UI/padelclub_desktop/lib/features/product/data/models/product_model.dart)
- [UI/padelclub_desktop/lib/features/product/data/models/search_result.dart](../../UI/padelclub_desktop/lib/features/product/data/models/search_result.dart)
- [UI/padelclub_desktop/lib/features/product/data/repositories/product_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product/data/repositories/product_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/product/domain/entities/product.dart](../../UI/padelclub_desktop/lib/features/product/domain/entities/product.dart)
- [UI/padelclub_desktop/lib/features/product/domain/repositories/product_repository.dart](../../UI/padelclub_desktop/lib/features/product/domain/repositories/product_repository.dart)
- [UI/padelclub_desktop/lib/features/product/domain/usecases/get_products.dart](../../UI/padelclub_desktop/lib/features/product/domain/usecases/get_products.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/logged_product_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/logged_product_provider.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/product_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/product_provider.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_details_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_details_screen.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_list_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_list_screen.dart)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_management_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_management_screen.dart)
- [UI/padelclub_desktop/lib/features/product_categories/data/datasources/product_category_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/datasources/product_category_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/product_categories/data/models/product_category_model.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/models/product_category_model.dart)
- [UI/padelclub_desktop/lib/features/product_categories/data/repositories/product_category_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/repositories/product_category_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/product_categories/domain/entities/product_category.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/entities/product_category.dart)
- [UI/padelclub_desktop/lib/features/product_categories/domain/repositories/product_category_repository.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/repositories/product_category_repository.dart)
- [UI/padelclub_desktop/lib/features/product_categories/domain/usecases/get_product_categories.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/usecases/get_product_categories.dart)
- [UI/padelclub_desktop/lib/features/product_categories/presentation/providers/product_category_provider.dart](../../UI/padelclub_desktop/lib/features/product_categories/presentation/providers/product_category_provider.dart)
- [UI/padelclub_desktop/lib/features/product_types/data/datasources/product_type_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product_types/data/datasources/product_type_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/product_types/data/models/product_type_model.dart](../../UI/padelclub_desktop/lib/features/product_types/data/models/product_type_model.dart)
- [UI/padelclub_desktop/lib/features/product_types/data/repositories/product_type_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product_types/data/repositories/product_type_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/product_types/domain/entities/product_type.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/entities/product_type.dart)
- [UI/padelclub_desktop/lib/features/product_types/domain/repositories/product_type_repository.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/repositories/product_type_repository.dart)
- [UI/padelclub_desktop/lib/features/product_types/domain/usecases/get_product_types.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/usecases/get_product_types.dart)
- [UI/padelclub_desktop/lib/features/product_types/presentation/providers/product_type_provider.dart](../../UI/padelclub_desktop/lib/features/product_types/presentation/providers/product_type_provider.dart)
- [UI/padelclub_desktop/lib/features/profile/presentation/screens/profile_screen.dart](../../UI/padelclub_desktop/lib/features/profile/presentation/screens/profile_screen.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/repositories/recommendation_evaluation_repository_impl.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/repositories/recommendation_evaluation_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_evaluation_evidence_panel.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_evaluation_evidence_panel.dart)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_operational_readiness_panel.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_operational_readiness_panel.dart)
- [UI/padelclub_desktop/lib/features/recommendations/domain/entities/product_recommendation.dart](../../UI/padelclub_desktop/lib/features/recommendations/domain/entities/product_recommendation.dart)
- [UI/padelclub_desktop/lib/features/recommendations/presentation/providers/product_recommendation_provider.dart](../../UI/padelclub_desktop/lib/features/recommendations/presentation/providers/product_recommendation_provider.dart)
- [UI/padelclub_desktop/lib/features/reservations/data/datasources/reservation_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/reservations/data/datasources/reservation_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/reservations/data/models/reservation_model.dart](../../UI/padelclub_desktop/lib/features/reservations/data/models/reservation_model.dart)
- [UI/padelclub_desktop/lib/features/reservations/data/repositories/reservation_repository_impl.dart](../../UI/padelclub_desktop/lib/features/reservations/data/repositories/reservation_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/account_credit.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/account_credit.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/court_availability.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/court_availability.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/reservation.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/reservation.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/waitlist_entry.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/waitlist_entry.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/repositories/reservation_repository.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/repositories/reservation_repository.dart)
- [UI/padelclub_desktop/lib/features/reservations/domain/usecases/get_reservations.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/usecases/get_reservations.dart)
- [UI/padelclub_desktop/lib/features/reservations/presentation/providers/reservation_provider.dart](../../UI/padelclub_desktop/lib/features/reservations/presentation/providers/reservation_provider.dart)
- [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart](../../UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart)
- [UI/padelclub_desktop/lib/features/returns/data/datasources/return_requests_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/returns/data/datasources/return_requests_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/returns/data/models/return_eligible_order_model.dart](../../UI/padelclub_desktop/lib/features/returns/data/models/return_eligible_order_model.dart)
- [UI/padelclub_desktop/lib/features/returns/data/models/return_request_status_model.dart](../../UI/padelclub_desktop/lib/features/returns/data/models/return_request_status_model.dart)
- [UI/padelclub_desktop/lib/features/returns/data/repositories/return_requests_repository_impl.dart](../../UI/padelclub_desktop/lib/features/returns/data/repositories/return_requests_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/entities/return_eligible_order.dart](../../UI/padelclub_desktop/lib/features/returns/domain/entities/return_eligible_order.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/entities/return_request_status.dart](../../UI/padelclub_desktop/lib/features/returns/domain/entities/return_request_status.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/repositories/return_requests_repository.dart](../../UI/padelclub_desktop/lib/features/returns/domain/repositories/return_requests_repository.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/create_return_request.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/create_return_request.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_eligible_return_orders.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_eligible_return_orders.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_my_return_requests.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_my_return_requests.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_return_requests.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_return_requests.dart)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/resolve_return_request.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/resolve_return_request.dart)
- [UI/padelclub_desktop/lib/features/returns/presentation/providers/return_requests_provider.dart](../../UI/padelclub_desktop/lib/features/returns/presentation/providers/return_requests_provider.dart)
- [UI/padelclub_desktop/lib/features/reviews/data/models/club_review_model.dart](../../UI/padelclub_desktop/lib/features/reviews/data/models/club_review_model.dart)
- [UI/padelclub_desktop/lib/features/reviews/domain/entities/club_review.dart](../../UI/padelclub_desktop/lib/features/reviews/domain/entities/club_review.dart)
- [UI/padelclub_desktop/lib/features/reviews/presentation/providers/club_review_provider.dart](../../UI/padelclub_desktop/lib/features/reviews/presentation/providers/club_review_provider.dart)
- [UI/padelclub_desktop/lib/features/roles/data/datasources/role_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/roles/data/datasources/role_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/roles/data/models/role_model.dart](../../UI/padelclub_desktop/lib/features/roles/data/models/role_model.dart)
- [UI/padelclub_desktop/lib/features/roles/data/repositories/role_repository_impl.dart](../../UI/padelclub_desktop/lib/features/roles/data/repositories/role_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/roles/domain/entities/role.dart](../../UI/padelclub_desktop/lib/features/roles/domain/entities/role.dart)
- [UI/padelclub_desktop/lib/features/roles/domain/repositories/role_repository.dart](../../UI/padelclub_desktop/lib/features/roles/domain/repositories/role_repository.dart)
- [UI/padelclub_desktop/lib/features/roles/domain/usecases/get_roles.dart](../../UI/padelclub_desktop/lib/features/roles/domain/usecases/get_roles.dart)
- [UI/padelclub_desktop/lib/features/roles/presentation/providers/role_provider.dart](../../UI/padelclub_desktop/lib/features/roles/presentation/providers/role_provider.dart)
- [UI/padelclub_desktop/lib/features/search/data/models/discovery_models.dart](../../UI/padelclub_desktop/lib/features/search/data/models/discovery_models.dart)
- [UI/padelclub_desktop/lib/features/search/domain/entities/discovery_match.dart](../../UI/padelclub_desktop/lib/features/search/domain/entities/discovery_match.dart)
- [UI/padelclub_desktop/lib/features/search/domain/entities/player_ranking.dart](../../UI/padelclub_desktop/lib/features/search/domain/entities/player_ranking.dart)
- [UI/padelclub_desktop/lib/features/search/presentation/providers/discovery_provider.dart](../../UI/padelclub_desktop/lib/features/search/presentation/providers/discovery_provider.dart)
- [UI/padelclub_desktop/lib/features/search/presentation/screens/search_screen.dart](../../UI/padelclub_desktop/lib/features/search/presentation/screens/search_screen.dart)
- [UI/padelclub_desktop/lib/features/tournament/data/datasources/tournament_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament/data/datasources/tournament_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/tournament/data/models/tournament_model.dart](../../UI/padelclub_desktop/lib/features/tournament/data/models/tournament_model.dart)
- [UI/padelclub_desktop/lib/features/tournament/data/repositories/tournament_repository_impl.dart](../../UI/padelclub_desktop/lib/features/tournament/data/repositories/tournament_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/tournament/domain/entities/tournament.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/entities/tournament.dart)
- [UI/padelclub_desktop/lib/features/tournament/domain/repositories/tournament_repository.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/repositories/tournament_repository.dart)
- [UI/padelclub_desktop/lib/features/tournament/domain/usecases/get_tournaments.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/usecases/get_tournaments.dart)
- [UI/padelclub_desktop/lib/features/tournament/presentation/providers/tournament_provider.dart](../../UI/padelclub_desktop/lib/features/tournament/presentation/providers/tournament_provider.dart)
- [UI/padelclub_desktop/lib/features/tournament_management/data/tournament_management_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament_management/data/tournament_management_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/tournament_management/domain/entities/tournament_draft.dart](../../UI/padelclub_desktop/lib/features/tournament_management/domain/entities/tournament_draft.dart)
- [UI/padelclub_desktop/lib/features/tournament_management/presentation/providers/tournament_management_provider.dart](../../UI/padelclub_desktop/lib/features/tournament_management/presentation/providers/tournament_management_provider.dart)
- [UI/padelclub_desktop/lib/features/tournament_management/presentation/screens/tournament_management_screen.dart](../../UI/padelclub_desktop/lib/features/tournament_management/presentation/screens/tournament_management_screen.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/models/tournament_participant_model.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/models/tournament_participant_model.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/repositories/tournament_participant_repository_impl.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/repositories/tournament_participant_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/entities/tournament_participant.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/entities/tournament_participant.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/repositories/tournament_participant_repository.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/repositories/tournament_participant_repository.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/usecases/get_tournament_participants.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/usecases/get_tournament_participants.dart)
- [UI/padelclub_desktop/lib/features/tournament_participants/presentation/providers/tournament_participant_provider.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/presentation/providers/tournament_participant_provider.dart)
- [UI/padelclub_desktop/lib/features/users/data/datasources/user_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/users/data/datasources/user_remote_data_source.dart)
- [UI/padelclub_desktop/lib/features/users/data/models/user_model.dart](../../UI/padelclub_desktop/lib/features/users/data/models/user_model.dart)
- [UI/padelclub_desktop/lib/features/users/data/repositories/user_repository_impl.dart](../../UI/padelclub_desktop/lib/features/users/data/repositories/user_repository_impl.dart)
- [UI/padelclub_desktop/lib/features/users/domain/entities/user.dart](../../UI/padelclub_desktop/lib/features/users/domain/entities/user.dart)
- [UI/padelclub_desktop/lib/features/users/domain/repositories/user_repository.dart](../../UI/padelclub_desktop/lib/features/users/domain/repositories/user_repository.dart)
- [UI/padelclub_desktop/lib/features/users/domain/usecases/get_users.dart](../../UI/padelclub_desktop/lib/features/users/domain/usecases/get_users.dart)
- [UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart](../../UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart)
- [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart](../../UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart)
- [UI/padelclub_desktop/lib/layouts/master_screen.dart](../../UI/padelclub_desktop/lib/layouts/master_screen.dart)
- [UI/padelclub_desktop/lib/main.dart](../../UI/padelclub_desktop/lib/main.dart)
- [UI/padelclub_desktop/lib/providers/auth_provider.dart](../../UI/padelclub_desktop/lib/providers/auth_provider.dart)
- [UI/padelclub_desktop/lib/screens/product_details_screen.dart](../../UI/padelclub_desktop/lib/screens/product_details_screen.dart)
- [UI/padelclub_mobile/lib/main.dart](../../UI/padelclub_mobile/lib/main.dart)

## Complete indexed file manifest

Line counts describe file size, not review depth. SHA-256 fingerprints are retained in source-index.json.

- [.github/dependabot.yml](../../.github/dependabot.yml) (14 lines)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml) (114 lines)
- [PadelClub.Model/Exceptions/UserException.cs](../../PadelClub.Model/Exceptions/UserException.cs) (17 lines)
- [PadelClub.Model/Messages/ProductUpdated.cs](../../PadelClub.Model/Messages/ProductUpdated.cs) (16 lines)
- [PadelClub.Model/PadelClub.Model.csproj](../../PadelClub.Model/PadelClub.Model.csproj) (17 lines)
- [PadelClub.Model/Product.cs](../../PadelClub.Model/Product.cs) (14 lines)
- [PadelClub.Model/Requests/AuthRequests.cs](../../PadelClub.Model/Requests/AuthRequests.cs) (13 lines)
- [PadelClub.Model/Requests/BookingLifecycleRequests.cs](../../PadelClub.Model/Requests/BookingLifecycleRequests.cs) (26 lines)
- [PadelClub.Model/Requests/CheckoutRequest.cs](../../PadelClub.Model/Requests/CheckoutRequest.cs) (54 lines)
- [PadelClub.Model/Requests/ClubReviewRequest.cs](../../PadelClub.Model/Requests/ClubReviewRequest.cs) (14 lines)
- [PadelClub.Model/Requests/CourtInsertRequest.cs](../../PadelClub.Model/Requests/CourtInsertRequest.cs) (13 lines)
- [PadelClub.Model/Requests/CourtUpdateRequest.cs](../../PadelClub.Model/Requests/CourtUpdateRequest.cs) (13 lines)
- [PadelClub.Model/Requests/MatchParticipantInsertRequest.cs](../../PadelClub.Model/Requests/MatchParticipantInsertRequest.cs) (10 lines)
- [PadelClub.Model/Requests/MatchParticipantUpdateRequest.cs](../../PadelClub.Model/Requests/MatchParticipantUpdateRequest.cs) (10 lines)
- [PadelClub.Model/Requests/MembershipInsertRequest.cs](../../PadelClub.Model/Requests/MembershipInsertRequest.cs) (14 lines)
- [PadelClub.Model/Requests/MembershipUpdateRequest.cs](../../PadelClub.Model/Requests/MembershipUpdateRequest.cs) (14 lines)
- [PadelClub.Model/Requests/NotificationInsertRequest.cs](../../PadelClub.Model/Requests/NotificationInsertRequest.cs) (12 lines)
- [PadelClub.Model/Requests/NotificationUpdateRequest.cs](../../PadelClub.Model/Requests/NotificationUpdateRequest.cs) (9 lines)
- [PadelClub.Model/Requests/OrderInsertRequest.cs](../../PadelClub.Model/Requests/OrderInsertRequest.cs) (12 lines)
- [PadelClub.Model/Requests/OrderItemInsertRequest.cs](../../PadelClub.Model/Requests/OrderItemInsertRequest.cs) (11 lines)
- [PadelClub.Model/Requests/OrderItemUpdateRequest.cs](../../PadelClub.Model/Requests/OrderItemUpdateRequest.cs) (11 lines)
- [PadelClub.Model/Requests/OrderUpdateRequest.cs](../../PadelClub.Model/Requests/OrderUpdateRequest.cs) (12 lines)
- [PadelClub.Model/Requests/PaymentInsertRequest.cs](../../PadelClub.Model/Requests/PaymentInsertRequest.cs) (18 lines)
- [PadelClub.Model/Requests/PaymentUpdateRequest.cs](../../PadelClub.Model/Requests/PaymentUpdateRequest.cs) (18 lines)
- [PadelClub.Model/Requests/ProductCategoryInsertRequest.cs](../../PadelClub.Model/Requests/ProductCategoryInsertRequest.cs) (9 lines)
- [PadelClub.Model/Requests/ProductCategoryUpdateRequest.cs](../../PadelClub.Model/Requests/ProductCategoryUpdateRequest.cs) (9 lines)
- [PadelClub.Model/Requests/ProductInsertRequest.cs](../../PadelClub.Model/Requests/ProductInsertRequest.cs) (16 lines)
- [PadelClub.Model/Requests/ProductTypeInsertRequest.cs](../../PadelClub.Model/Requests/ProductTypeInsertRequest.cs) (9 lines)
- [PadelClub.Model/Requests/ProductTypeUpdateRequest.cs](../../PadelClub.Model/Requests/ProductTypeUpdateRequest.cs) (9 lines)
- [PadelClub.Model/Requests/ProductUpdateRequest.cs](../../PadelClub.Model/Requests/ProductUpdateRequest.cs) (16 lines)
- [PadelClub.Model/Requests/ProviderVerificationRequest.cs](../../PadelClub.Model/Requests/ProviderVerificationRequest.cs) (11 lines)
- [PadelClub.Model/Requests/RecommendationAnalyticsConsentRequest.cs](../../PadelClub.Model/Requests/RecommendationAnalyticsConsentRequest.cs) (9 lines)
- [PadelClub.Model/Requests/RecommendationEvaluationRequest.cs](../../PadelClub.Model/Requests/RecommendationEvaluationRequest.cs) (16 lines)
- [PadelClub.Model/Requests/ReservationInsertRequest.cs](../../PadelClub.Model/Requests/ReservationInsertRequest.cs) (15 lines)
- [PadelClub.Model/Requests/ReservationRequest.cs](../../PadelClub.Model/Requests/ReservationRequest.cs) (16 lines)
- [PadelClub.Model/Requests/ReservationUpdateRequest.cs](../../PadelClub.Model/Requests/ReservationUpdateRequest.cs) (15 lines)
- [PadelClub.Model/Requests/RoleInsertRequest.cs](../../PadelClub.Model/Requests/RoleInsertRequest.cs) (11 lines)
- [PadelClub.Model/Requests/RoleUpdateRequest.cs](../../PadelClub.Model/Requests/RoleUpdateRequest.cs) (11 lines)
- [PadelClub.Model/Requests/StripePaymentRequests.cs](../../PadelClub.Model/Requests/StripePaymentRequests.cs) (22 lines)
- [PadelClub.Model/Requests/TournamentInsertRequest.cs](../../PadelClub.Model/Requests/TournamentInsertRequest.cs) (17 lines)
- [PadelClub.Model/Requests/TournamentParticipantInsertRequest.cs](../../PadelClub.Model/Requests/TournamentParticipantInsertRequest.cs) (12 lines)
- [PadelClub.Model/Requests/TournamentParticipantUpdateRequest.cs](../../PadelClub.Model/Requests/TournamentParticipantUpdateRequest.cs) (12 lines)
- [PadelClub.Model/Requests/TournamentUpdateRequest.cs](../../PadelClub.Model/Requests/TournamentUpdateRequest.cs) (17 lines)
- [PadelClub.Model/Requests/UserInsertRequest.cs](../../PadelClub.Model/Requests/UserInsertRequest.cs) (18 lines)
- [PadelClub.Model/Requests/UserLoginRequest.cs](../../PadelClub.Model/Requests/UserLoginRequest.cs) (12 lines)
- [PadelClub.Model/Requests/UserRequest.cs](../../PadelClub.Model/Requests/UserRequest.cs) (19 lines)
- [PadelClub.Model/Requests/UserSelfUpdateRequest.cs](../../PadelClub.Model/Requests/UserSelfUpdateRequest.cs) (12 lines)
- [PadelClub.Model/Requests/UserUpdateRequest.cs](../../PadelClub.Model/Requests/UserUpdateRequest.cs) (20 lines)
- [PadelClub.Model/Responses/AuthResponse.cs](../../PadelClub.Model/Responses/AuthResponse.cs) (11 lines)
- [PadelClub.Model/Responses/AvailabilitySlotResponse.cs](../../PadelClub.Model/Responses/AvailabilitySlotResponse.cs) (17 lines)
- [PadelClub.Model/Responses/BookingLifecycleResponses.cs](../../PadelClub.Model/Responses/BookingLifecycleResponses.cs) (22 lines)
- [PadelClub.Model/Responses/ClubReviewResponse.cs](../../PadelClub.Model/Responses/ClubReviewResponse.cs) (14 lines)
- [PadelClub.Model/Responses/CourtAvailabilityResponse.cs](../../PadelClub.Model/Responses/CourtAvailabilityResponse.cs) (14 lines)
- [PadelClub.Model/Responses/CourtResponse.cs](../../PadelClub.Model/Responses/CourtResponse.cs) (18 lines)
- [PadelClub.Model/Responses/EligibleReturnOrderResponse.cs](../../PadelClub.Model/Responses/EligibleReturnOrderResponse.cs) (41 lines)
- [PadelClub.Model/Responses/MatchParticipantResponse.cs](../../PadelClub.Model/Responses/MatchParticipantResponse.cs) (14 lines)
- [PadelClub.Model/Responses/MatchSummaryResponse.cs](../../PadelClub.Model/Responses/MatchSummaryResponse.cs) (27 lines)
- [PadelClub.Model/Responses/MembershipResponse.cs](../../PadelClub.Model/Responses/MembershipResponse.cs) (22 lines)
- [PadelClub.Model/Responses/NotificationResponse.cs](../../PadelClub.Model/Responses/NotificationResponse.cs) (18 lines)
- [PadelClub.Model/Responses/OrderItemResponse.cs](../../PadelClub.Model/Responses/OrderItemResponse.cs) (15 lines)
- [PadelClub.Model/Responses/OrderResponse.cs](../../PadelClub.Model/Responses/OrderResponse.cs) (25 lines)
- [PadelClub.Model/Responses/PagedResult.cs](../../PadelClub.Model/Responses/PagedResult.cs) (10 lines)
- [PadelClub.Model/Responses/PaymentResponse.cs](../../PadelClub.Model/Responses/PaymentResponse.cs) (26 lines)
- [PadelClub.Model/Responses/ProductCategoryResponse.cs](../../PadelClub.Model/Responses/ProductCategoryResponse.cs) (14 lines)
- [PadelClub.Model/Responses/ProductRecommendationResponse.cs](../../PadelClub.Model/Responses/ProductRecommendationResponse.cs) (26 lines)
- [PadelClub.Model/Responses/ProductResponse.cs](../../PadelClub.Model/Responses/ProductResponse.cs) (18 lines)
- [PadelClub.Model/Responses/ProductTypeResponse.cs](../../PadelClub.Model/Responses/ProductTypeResponse.cs) (14 lines)
- [PadelClub.Model/Responses/ProviderReadinessResponse.cs](../../PadelClub.Model/Responses/ProviderReadinessResponse.cs) (25 lines)
- [PadelClub.Model/Responses/ProviderRefundOperationResponse.cs](../../PadelClub.Model/Responses/ProviderRefundOperationResponse.cs) (25 lines)
- [PadelClub.Model/Responses/ProviderVerificationAttemptResponse.cs](../../PadelClub.Model/Responses/ProviderVerificationAttemptResponse.cs) (28 lines)
- [PadelClub.Model/Responses/RecommendationAnalyticsConsentResponse.cs](../../PadelClub.Model/Responses/RecommendationAnalyticsConsentResponse.cs) (17 lines)
- [PadelClub.Model/Responses/RecommendationCohortReadinessResponse.cs](../../PadelClub.Model/Responses/RecommendationCohortReadinessResponse.cs) (136 lines)
- [PadelClub.Model/Responses/RecommendationEvaluationResponse.cs](../../PadelClub.Model/Responses/RecommendationEvaluationResponse.cs) (224 lines)
- [PadelClub.Model/Responses/RecommendationExperimentAnalysisRunResponse.cs](../../PadelClub.Model/Responses/RecommendationExperimentAnalysisRunResponse.cs) (25 lines)
- [PadelClub.Model/Responses/RecommendationExperimentImpactResponse.cs](../../PadelClub.Model/Responses/RecommendationExperimentImpactResponse.cs) (89 lines)
- [PadelClub.Model/Responses/RecommendationExperimentResponse.cs](../../PadelClub.Model/Responses/RecommendationExperimentResponse.cs) (42 lines)
- [PadelClub.Model/Responses/RecommendationImpactResponse.cs](../../PadelClub.Model/Responses/RecommendationImpactResponse.cs) (66 lines)
- [PadelClub.Model/Responses/ReservationResponse.cs](../../PadelClub.Model/Responses/ReservationResponse.cs) (22 lines)
- [PadelClub.Model/Responses/RoleResponse.cs](../../PadelClub.Model/Responses/RoleResponse.cs) (9 lines)
- [PadelClub.Model/Responses/StripePaymentResponse.cs](../../PadelClub.Model/Responses/StripePaymentResponse.cs) (11 lines)
- [PadelClub.Model/Responses/TournamentParticipantResponse.cs](../../PadelClub.Model/Responses/TournamentParticipantResponse.cs) (14 lines)
- [PadelClub.Model/Responses/TournamentResponse.cs](../../PadelClub.Model/Responses/TournamentResponse.cs) (21 lines)
- [PadelClub.Model/Responses/UserResponse.cs](../../PadelClub.Model/Responses/UserResponse.cs) (21 lines)
- [PadelClub.Model/SearchObjects/BaseSearchObject.cs](../../PadelClub.Model/SearchObjects/BaseSearchObject.cs) (11 lines)
- [PadelClub.Model/SearchObjects/ClubReviewSearchObject.cs](../../PadelClub.Model/SearchObjects/ClubReviewSearchObject.cs) (6 lines)
- [PadelClub.Model/SearchObjects/CourtSearchObject.cs](../../PadelClub.Model/SearchObjects/CourtSearchObject.cs) (10 lines)
- [PadelClub.Model/SearchObjects/MatchParticipantSearchObject.cs](../../PadelClub.Model/SearchObjects/MatchParticipantSearchObject.cs) (10 lines)
- [PadelClub.Model/SearchObjects/MembershipSearchObject.cs](../../PadelClub.Model/SearchObjects/MembershipSearchObject.cs) (15 lines)
- [PadelClub.Model/SearchObjects/NotificationSearchObject.cs](../../PadelClub.Model/SearchObjects/NotificationSearchObject.cs) (12 lines)
- [PadelClub.Model/SearchObjects/OrderItemSearchObject.cs](../../PadelClub.Model/SearchObjects/OrderItemSearchObject.cs) (8 lines)
- [PadelClub.Model/SearchObjects/OrderSearchObject.cs](../../PadelClub.Model/SearchObjects/OrderSearchObject.cs) (13 lines)
- [PadelClub.Model/SearchObjects/PaymentSearchObject.cs](../../PadelClub.Model/SearchObjects/PaymentSearchObject.cs) (18 lines)
- [PadelClub.Model/SearchObjects/ProductCategorySearchObject.cs](../../PadelClub.Model/SearchObjects/ProductCategorySearchObject.cs) (8 lines)
- [PadelClub.Model/SearchObjects/ProductSearchObject.cs](../../PadelClub.Model/SearchObjects/ProductSearchObject.cs) (12 lines)
- [PadelClub.Model/SearchObjects/ProductTypeSearchObject.cs](../../PadelClub.Model/SearchObjects/ProductTypeSearchObject.cs) (8 lines)
- [PadelClub.Model/SearchObjects/ReservationSearchObject.cs](../../PadelClub.Model/SearchObjects/ReservationSearchObject.cs) (18 lines)
- [PadelClub.Model/SearchObjects/RoleSearchObject.cs](../../PadelClub.Model/SearchObjects/RoleSearchObject.cs) (8 lines)
- [PadelClub.Model/SearchObjects/TournamentParticipantSearchObject.cs](../../PadelClub.Model/SearchObjects/TournamentParticipantSearchObject.cs) (9 lines)
- [PadelClub.Model/SearchObjects/TournamentSearchObject.cs](../../PadelClub.Model/SearchObjects/TournamentSearchObject.cs) (13 lines)
- [PadelClub.Model/SearchObjects/UserSearchObject.cs](../../PadelClub.Model/SearchObjects/UserSearchObject.cs) (17 lines)
- [PadelClub.Model/User.cs](../../PadelClub.Model/User.cs) (20 lines)
- [PadelClub.Services/BaseCRUDService.cs](../../PadelClub.Services/BaseCRUDService.cs) (98 lines)
- [PadelClub.Services/BaseService.cs](../../PadelClub.Services/BaseService.cs) (75 lines)
- [PadelClub.Services/BookingOptions.cs](../../PadelClub.Services/BookingOptions.cs) (12 lines)
- [PadelClub.Services/ClubReviewService.cs](../../PadelClub.Services/ClubReviewService.cs) (102 lines)
- [PadelClub.Services/CommerceCalculator.cs](../../PadelClub.Services/CommerceCalculator.cs) (14 lines)
- [PadelClub.Services/CourtService.cs](../../PadelClub.Services/CourtService.cs) (52 lines)
- [PadelClub.Services/Database/Asset.cs](../../PadelClub.Services/Database/Asset.cs) (19 lines)
- [PadelClub.Services/Database/AuditLog.cs](../../PadelClub.Services/Database/AuditLog.cs) (14 lines)
- [PadelClub.Services/Database/AuthToken.cs](../../PadelClub.Services/Database/AuthToken.cs) (16 lines)
- [PadelClub.Services/Database/BookingLifecycle.cs](../../PadelClub.Services/Database/BookingLifecycle.cs) (40 lines)
- [PadelClub.Services/Database/ClubReview.cs](../../PadelClub.Services/Database/ClubReview.cs) (15 lines)
- [PadelClub.Services/Database/Coupon.cs](../../PadelClub.Services/Database/Coupon.cs) (29 lines)
- [PadelClub.Services/Database/Court.cs](../../PadelClub.Services/Database/Court.cs) (23 lines)
- [PadelClub.Services/Database/InboxMessage.cs](../../PadelClub.Services/Database/InboxMessage.cs) (19 lines)
- [PadelClub.Services/Database/InventoryMovement.cs](../../PadelClub.Services/Database/InventoryMovement.cs) (15 lines)
- [PadelClub.Services/Database/Match.cs](../../PadelClub.Services/Database/Match.cs) (41 lines)
- [PadelClub.Services/Database/MatchParticipant.cs](../../PadelClub.Services/Database/MatchParticipant.cs) (19 lines)
- [PadelClub.Services/Database/Membership.cs](../../PadelClub.Services/Database/Membership.cs) (28 lines)
- [PadelClub.Services/Database/MembershipEvent.cs](../../PadelClub.Services/Database/MembershipEvent.cs) (12 lines)
- [PadelClub.Services/Database/Migrations/20260514105859_InitialCreate.cs](../../PadelClub.Services/Database/Migrations/20260514105859_InitialCreate.cs) (729 lines)
- [PadelClub.Services/Database/Migrations/20260514105859_InitialCreate.Designer.cs](../../PadelClub.Services/Database/Migrations/20260514105859_InitialCreate.Designer.cs) (1123 lines)
- [PadelClub.Services/Database/Migrations/20260810100841_AddNotifications.cs](../../PadelClub.Services/Database/Migrations/20260810100841_AddNotifications.cs) (91 lines)
- [PadelClub.Services/Database/Migrations/20260810100841_AddNotifications.Designer.cs](../../PadelClub.Services/Database/Migrations/20260810100841_AddNotifications.Designer.cs) (1223 lines)
- [PadelClub.Services/Database/Migrations/20260812064457_AddClubReviews.cs](../../PadelClub.Services/Database/Migrations/20260812064457_AddClubReviews.cs) (57 lines)
- [PadelClub.Services/Database/Migrations/20260812064457_AddClubReviews.Designer.cs](../../PadelClub.Services/Database/Migrations/20260812064457_AddClubReviews.Designer.cs) (1280 lines)
- [PadelClub.Services/Database/Migrations/20260813191703_ExpandOrderDeliveryDetails.cs](../../PadelClub.Services/Database/Migrations/20260813191703_ExpandOrderDeliveryDetails.cs) (66 lines)
- [PadelClub.Services/Database/Migrations/20260813191703_ExpandOrderDeliveryDetails.Designer.cs](../../PadelClub.Services/Database/Migrations/20260813191703_ExpandOrderDeliveryDetails.Designer.cs) (1300 lines)
- [PadelClub.Services/Database/Migrations/20260814083548_AddProductionAuthentication.cs](../../PadelClub.Services/Database/Migrations/20260814083548_AddProductionAuthentication.cs) (69 lines)
- [PadelClub.Services/Database/Migrations/20260814083548_AddProductionAuthentication.Designer.cs](../../PadelClub.Services/Database/Migrations/20260814083548_AddProductionAuthentication.Designer.cs) (1362 lines)
- [PadelClub.Services/Database/Migrations/20260814090302_AddRefreshTokenFamilies.cs](../../PadelClub.Services/Database/Migrations/20260814090302_AddRefreshTokenFamilies.cs) (38 lines)
- [PadelClub.Services/Database/Migrations/20260814090302_AddRefreshTokenFamilies.Designer.cs](../../PadelClub.Services/Database/Migrations/20260814090302_AddRefreshTokenFamilies.Designer.cs) (1368 lines)
- [PadelClub.Services/Database/Migrations/20260814140627_AddBookingLifecycle.cs](../../PadelClub.Services/Database/Migrations/20260814140627_AddBookingLifecycle.cs) (179 lines)
- [PadelClub.Services/Database/Migrations/20260814140627_AddBookingLifecycle.Designer.cs](../../PadelClub.Services/Database/Migrations/20260814140627_AddBookingLifecycle.Designer.cs) (1549 lines)
- [PadelClub.Services/Database/Migrations/20260814154332_AddStripePayments.cs](../../PadelClub.Services/Database/Migrations/20260814154332_AddStripePayments.cs) (134 lines)
- [PadelClub.Services/Database/Migrations/20260814154332_AddStripePayments.Designer.cs](../../PadelClub.Services/Database/Migrations/20260814154332_AddStripePayments.Designer.cs) (1617 lines)
- [PadelClub.Services/Database/Migrations/20260814163520_AddNotificationDelivery.cs](../../PadelClub.Services/Database/Migrations/20260814163520_AddNotificationDelivery.cs) (140 lines)
- [PadelClub.Services/Database/Migrations/20260814163520_AddNotificationDelivery.Designer.cs](../../PadelClub.Services/Database/Migrations/20260814163520_AddNotificationDelivery.Designer.cs) (1790 lines)
- [PadelClub.Services/Database/Migrations/20260815154741_AddPlayerExperience.cs](../../PadelClub.Services/Database/Migrations/20260815154741_AddPlayerExperience.cs) (184 lines)
- [PadelClub.Services/Database/Migrations/20260815154741_AddPlayerExperience.Designer.cs](../../PadelClub.Services/Database/Migrations/20260815154741_AddPlayerExperience.Designer.cs) (1947 lines)
- [PadelClub.Services/Database/Migrations/20260815155553_AddTournamentAndMembershipLifecycle.cs](../../PadelClub.Services/Database/Migrations/20260815155553_AddTournamentAndMembershipLifecycle.cs) (224 lines)
- [PadelClub.Services/Database/Migrations/20260815155553_AddTournamentAndMembershipLifecycle.Designer.cs](../../PadelClub.Services/Database/Migrations/20260815155553_AddTournamentAndMembershipLifecycle.Designer.cs) (2051 lines)
- [PadelClub.Services/Database/Migrations/20260815160113_AddCommerceOperations.cs](../../PadelClub.Services/Database/Migrations/20260815160113_AddCommerceOperations.cs) (286 lines)
- [PadelClub.Services/Database/Migrations/20260815160113_AddCommerceOperations.Designer.cs](../../PadelClub.Services/Database/Migrations/20260815160113_AddCommerceOperations.Designer.cs) (2390 lines)
- [PadelClub.Services/Database/Migrations/20260815161841_AddPrivacyReadiness.cs](../../PadelClub.Services/Database/Migrations/20260815161841_AddPrivacyReadiness.cs) (56 lines)
- [PadelClub.Services/Database/Migrations/20260815161841_AddPrivacyReadiness.Designer.cs](../../PadelClub.Services/Database/Migrations/20260815161841_AddPrivacyReadiness.Designer.cs) (2445 lines)
- [PadelClub.Services/Database/Migrations/20260815190000_NormalizeMembershipStatus.cs](../../PadelClub.Services/Database/Migrations/20260815190000_NormalizeMembershipStatus.cs) (45 lines)
- [PadelClub.Services/Database/Migrations/20260830062859_AddOrderDemoProvenance.cs](../../PadelClub.Services/Database/Migrations/20260830062859_AddOrderDemoProvenance.cs) (44 lines)
- [PadelClub.Services/Database/Migrations/20260830062859_AddOrderDemoProvenance.Designer.cs](../../PadelClub.Services/Database/Migrations/20260830062859_AddOrderDemoProvenance.Designer.cs) (2454 lines)
- [PadelClub.Services/Database/Migrations/20260901155252_AddOperationalRecommendationEvidence.cs](../../PadelClub.Services/Database/Migrations/20260901155252_AddOperationalRecommendationEvidence.cs) (138 lines)
- [PadelClub.Services/Database/Migrations/20260901155252_AddOperationalRecommendationEvidence.Designer.cs](../../PadelClub.Services/Database/Migrations/20260901155252_AddOperationalRecommendationEvidence.Designer.cs) (2604 lines)
- [PadelClub.Services/Database/Migrations/20260902164815_AddRecommendationImpactAndMessagingReliability.cs](../../PadelClub.Services/Database/Migrations/20260902164815_AddRecommendationImpactAndMessagingReliability.cs) (133 lines)
- [PadelClub.Services/Database/Migrations/20260902164815_AddRecommendationImpactAndMessagingReliability.Designer.cs](../../PadelClub.Services/Database/Migrations/20260902164815_AddRecommendationImpactAndMessagingReliability.Designer.cs) (2722 lines)
- [PadelClub.Services/Database/Migrations/20260902202000_HardenRecommendationImpactIntegrity.cs](../../PadelClub.Services/Database/Migrations/20260902202000_HardenRecommendationImpactIntegrity.cs) (94 lines)
- [PadelClub.Services/Database/Migrations/20260905114625_AddProviderRefundOperations.cs](../../PadelClub.Services/Database/Migrations/20260905114625_AddProviderRefundOperations.cs) (99 lines)
- [PadelClub.Services/Database/Migrations/20260905114625_AddProviderRefundOperations.Designer.cs](../../PadelClub.Services/Database/Migrations/20260905114625_AddProviderRefundOperations.Designer.cs) (2870 lines)
- [PadelClub.Services/Database/Migrations/20260906064619_AddProviderRefundExpectedAmount.cs](../../PadelClub.Services/Database/Migrations/20260906064619_AddProviderRefundExpectedAmount.cs) (55 lines)
- [PadelClub.Services/Database/Migrations/20260906064619_AddProviderRefundExpectedAmount.Designer.cs](../../PadelClub.Services/Database/Migrations/20260906064619_AddProviderRefundExpectedAmount.Designer.cs) (2873 lines)
- [PadelClub.Services/Database/Migrations/20260906113821_AddProspectiveExperimentAndProviderVerification.cs](../../PadelClub.Services/Database/Migrations/20260906113821_AddProspectiveExperimentAndProviderVerification.cs) (266 lines)
- [PadelClub.Services/Database/Migrations/20260906113821_AddProspectiveExperimentAndProviderVerification.Designer.cs](../../PadelClub.Services/Database/Migrations/20260906113821_AddProspectiveExperimentAndProviderVerification.Designer.cs) (3220 lines)
- [PadelClub.Services/Database/Migrations/PadelClubContextModelSnapshot.cs](../../PadelClub.Services/Database/Migrations/PadelClubContextModelSnapshot.cs) (3217 lines)
- [PadelClub.Services/Database/Notification.cs](../../PadelClub.Services/Database/Notification.cs) (15 lines)
- [PadelClub.Services/Database/NotificationDelivery.cs](../../PadelClub.Services/Database/NotificationDelivery.cs) (17 lines)
- [PadelClub.Services/Database/NotificationPreference.cs](../../PadelClub.Services/Database/NotificationPreference.cs) (12 lines)
- [PadelClub.Services/Database/NotificationRecipient.cs](../../PadelClub.Services/Database/NotificationRecipient.cs) (14 lines)
- [PadelClub.Services/Database/Order.cs](../../PadelClub.Services/Database/Order.cs) (46 lines)
- [PadelClub.Services/Database/OrderItem.cs](../../PadelClub.Services/Database/OrderItem.cs) (20 lines)
- [PadelClub.Services/Database/OrderOrigin.cs](../../PadelClub.Services/Database/OrderOrigin.cs) (36 lines)
- [PadelClub.Services/Database/OutboxMessage.cs](../../PadelClub.Services/Database/OutboxMessage.cs) (34 lines)
- [PadelClub.Services/Database/PadelClubContext.cs](../../PadelClub.Services/Database/PadelClubContext.cs) (1272 lines)
- [PadelClub.Services/Database/PadelClubContextFactory.cs](../../PadelClub.Services/Database/PadelClubContextFactory.cs) (18 lines)
- [PadelClub.Services/Database/PartnerInvitation.cs](../../PadelClub.Services/Database/PartnerInvitation.cs) (14 lines)
- [PadelClub.Services/Database/Payment.cs](../../PadelClub.Services/Database/Payment.cs) (35 lines)
- [PadelClub.Services/Database/PlayerProfile.cs](../../PadelClub.Services/Database/PlayerProfile.cs) (16 lines)
- [PadelClub.Services/Database/PrivacyRequest.cs](../../PadelClub.Services/Database/PrivacyRequest.cs) (14 lines)
- [PadelClub.Services/Database/Product.cs](../../PadelClub.Services/Database/Product.cs) (29 lines)
- [PadelClub.Services/Database/ProductCategory.cs](../../PadelClub.Services/Database/ProductCategory.cs) (18 lines)
- [PadelClub.Services/Database/ProductType.cs](../../PadelClub.Services/Database/ProductType.cs) (18 lines)
- [PadelClub.Services/Database/ProviderRefundOperation.cs](../../PadelClub.Services/Database/ProviderRefundOperation.cs) (72 lines)
- [PadelClub.Services/Database/ProviderVerificationAttempt.cs](../../PadelClub.Services/Database/ProviderVerificationAttempt.cs) (54 lines)
- [PadelClub.Services/Database/PushDevice.cs](../../PadelClub.Services/Database/PushDevice.cs) (13 lines)
- [PadelClub.Services/Database/RecommendationAnalyticsConsent.cs](../../PadelClub.Services/Database/RecommendationAnalyticsConsent.cs) (23 lines)
- [PadelClub.Services/Database/RecommendationEvaluationRun.cs](../../PadelClub.Services/Database/RecommendationEvaluationRun.cs) (56 lines)
- [PadelClub.Services/Database/RecommendationExperiment.cs](../../PadelClub.Services/Database/RecommendationExperiment.cs) (51 lines)
- [PadelClub.Services/Database/RecommendationExperimentAnalysisRun.cs](../../PadelClub.Services/Database/RecommendationExperimentAnalysisRun.cs) (32 lines)
- [PadelClub.Services/Database/RecommendationExperimentAssignment.cs](../../PadelClub.Services/Database/RecommendationExperimentAssignment.cs) (25 lines)
- [PadelClub.Services/Database/RecommendationExperimentVariant.cs](../../PadelClub.Services/Database/RecommendationExperimentVariant.cs) (10 lines)
- [PadelClub.Services/Database/RecommendationExposure.cs](../../PadelClub.Services/Database/RecommendationExposure.cs) (65 lines)
- [PadelClub.Services/Database/RecommendationTelemetrySource.cs](../../PadelClub.Services/Database/RecommendationTelemetrySource.cs) (39 lines)
- [PadelClub.Services/Database/Reservation.cs](../../PadelClub.Services/Database/Reservation.cs) (28 lines)
- [PadelClub.Services/Database/ReturnRequest.cs](../../PadelClub.Services/Database/ReturnRequest.cs) (29 lines)
- [PadelClub.Services/Database/Role.cs](../../PadelClub.Services/Database/Role.cs) (18 lines)
- [PadelClub.Services/Database/StripeWebhookEvent.cs](../../PadelClub.Services/Database/StripeWebhookEvent.cs) (11 lines)
- [PadelClub.Services/Database/Tournament.cs](../../PadelClub.Services/Database/Tournament.cs) (25 lines)
- [PadelClub.Services/Database/TournamentParticipant.cs](../../PadelClub.Services/Database/TournamentParticipant.cs) (21 lines)
- [PadelClub.Services/Database/User.cs](../../PadelClub.Services/Database/User.cs) (48 lines)
- [PadelClub.Services/Database/UserRole.cs](../../PadelClub.Services/Database/UserRole.cs) (16 lines)
- [PadelClub.Services/IClubReviewService.cs](../../PadelClub.Services/IClubReviewService.cs) (13 lines)
- [PadelClub.Services/ICourtService.cs](../../PadelClub.Services/ICourtService.cs) (17 lines)
- [PadelClub.Services/ICRUDService.cs](../../PadelClub.Services/ICRUDService.cs) (12 lines)
- [PadelClub.Services/IMatchParticipantService.cs](../../PadelClub.Services/IMatchParticipantService.cs) (11 lines)
- [PadelClub.Services/IMembershipService.cs](../../PadelClub.Services/IMembershipService.cs) (11 lines)
- [PadelClub.Services/INotificationService.cs](../../PadelClub.Services/INotificationService.cs) (15 lines)
- [PadelClub.Services/IOrderItemService.cs](../../PadelClub.Services/IOrderItemService.cs) (11 lines)
- [PadelClub.Services/IOrderService.cs](../../PadelClub.Services/IOrderService.cs) (13 lines)
- [PadelClub.Services/IPasswordHasher.cs](../../PadelClub.Services/IPasswordHasher.cs) (31 lines)
- [PadelClub.Services/IPaymentService.cs](../../PadelClub.Services/IPaymentService.cs) (11 lines)
- [PadelClub.Services/IProductCategoryService.cs](../../PadelClub.Services/IProductCategoryService.cs) (11 lines)
- [PadelClub.Services/IProductService.cs](../../PadelClub.Services/IProductService.cs) (19 lines)
- [PadelClub.Services/IProductTypeService.cs](../../PadelClub.Services/IProductTypeService.cs) (11 lines)
- [PadelClub.Services/IReservationService.cs](../../PadelClub.Services/IReservationService.cs) (25 lines)
- [PadelClub.Services/IRoleService.cs](../../PadelClub.Services/IRoleService.cs) (11 lines)
- [PadelClub.Services/IService.cs](../../PadelClub.Services/IService.cs) (11 lines)
- [PadelClub.Services/ITournamentParticipantService.cs](../../PadelClub.Services/ITournamentParticipantService.cs) (11 lines)
- [PadelClub.Services/ITournamentService.cs](../../PadelClub.Services/ITournamentService.cs) (17 lines)
- [PadelClub.Services/IUserService.cs](../../PadelClub.Services/IUserService.cs) (17 lines)
- [PadelClub.Services/MatchParticipantService.cs](../../PadelClub.Services/MatchParticipantService.cs) (57 lines)
- [PadelClub.Services/MembershipService.cs](../../PadelClub.Services/MembershipService.cs) (74 lines)
- [PadelClub.Services/NotificationService.cs](../../PadelClub.Services/NotificationService.cs) (255 lines)
- [PadelClub.Services/OrderItemService.cs](../../PadelClub.Services/OrderItemService.cs) (36 lines)
- [PadelClub.Services/OrderService.cs](../../PadelClub.Services/OrderService.cs) (321 lines)
- [PadelClub.Services/Outbox/IInboxDeduplicationService.cs](../../PadelClub.Services/Outbox/IInboxDeduplicationService.cs) (17 lines)
- [PadelClub.Services/Outbox/InboxDeduplicationService.cs](../../PadelClub.Services/Outbox/InboxDeduplicationService.cs) (42 lines)
- [PadelClub.Services/Outbox/IOutboxLeaseService.cs](../../PadelClub.Services/Outbox/IOutboxLeaseService.cs) (35 lines)
- [PadelClub.Services/Outbox/OutboxMessageTypes.cs](../../PadelClub.Services/Outbox/OutboxMessageTypes.cs) (10 lines)
- [PadelClub.Services/Outbox/SqlServerOutboxLeaseService.cs](../../PadelClub.Services/Outbox/SqlServerOutboxLeaseService.cs) (147 lines)
- [PadelClub.Services/PadelClub.Services.csproj](../../PadelClub.Services/PadelClub.Services.csproj) (29 lines)
- [PadelClub.Services/PasswordHasher.cs](../../PadelClub.Services/PasswordHasher.cs) (115 lines)
- [PadelClub.Services/PaymentService.cs](../../PadelClub.Services/PaymentService.cs) (114 lines)
- [PadelClub.Services/ProductCategoryService.cs](../../PadelClub.Services/ProductCategoryService.cs) (38 lines)
- [PadelClub.Services/ProductService.cs](../../PadelClub.Services/ProductService.cs) (174 lines)
- [PadelClub.Services/ProductStateMachine/ActiveProductState.cs](../../PadelClub.Services/ProductStateMachine/ActiveProductState.cs) (27 lines)
- [PadelClub.Services/ProductStateMachine/BaseProductState.cs](../../PadelClub.Services/ProductStateMachine/BaseProductState.cs) (61 lines)
- [PadelClub.Services/ProductStateMachine/DeactivatedProductState.cs](../../PadelClub.Services/ProductStateMachine/DeactivatedProductState.cs) (41 lines)
- [PadelClub.Services/ProductStateMachine/DraftProductState.cs](../../PadelClub.Services/ProductStateMachine/DraftProductState.cs) (61 lines)
- [PadelClub.Services/ProductStateMachine/InitialProductState.cs](../../PadelClub.Services/ProductStateMachine/InitialProductState.cs) (27 lines)
- [PadelClub.Services/ProductTypeService.cs](../../PadelClub.Services/ProductTypeService.cs) (49 lines)
- [PadelClub.Services/Recommendations/IProductRecommendationService.cs](../../PadelClub.Services/Recommendations/IProductRecommendationService.cs) (37 lines)
- [PadelClub.Services/Recommendations/IRecommendationCohortReadinessService.cs](../../PadelClub.Services/Recommendations/IRecommendationCohortReadinessService.cs) (15 lines)
- [PadelClub.Services/Recommendations/IRecommendationEvaluationService.cs](../../PadelClub.Services/Recommendations/IRecommendationEvaluationService.cs) (23 lines)
- [PadelClub.Services/Recommendations/IRecommendationExperimentService.cs](../../PadelClub.Services/Recommendations/IRecommendationExperimentService.cs) (65 lines)
- [PadelClub.Services/Recommendations/IRecommendationImpactService.cs](../../PadelClub.Services/Recommendations/IRecommendationImpactService.cs) (12 lines)
- [PadelClub.Services/Recommendations/IRecommendationTelemetryEnvironment.cs](../../PadelClub.Services/Recommendations/IRecommendationTelemetryEnvironment.cs) (14 lines)
- [PadelClub.Services/Recommendations/ItemBasedCollaborativeRanker.cs](../../PadelClub.Services/Recommendations/ItemBasedCollaborativeRanker.cs) (163 lines)
- [PadelClub.Services/Recommendations/PopularityRecommendationRanker.cs](../../PadelClub.Services/Recommendations/PopularityRecommendationRanker.cs) (71 lines)
- [PadelClub.Services/Recommendations/PreparedItemBasedCollaborativeRanker.cs](../../PadelClub.Services/Recommendations/PreparedItemBasedCollaborativeRanker.cs) (217 lines)
- [PadelClub.Services/Recommendations/ProductRecommendationService.cs](../../PadelClub.Services/Recommendations/ProductRecommendationService.cs) (443 lines)
- [PadelClub.Services/Recommendations/RecommendationCohortReadinessService.cs](../../PadelClub.Services/Recommendations/RecommendationCohortReadinessService.cs) (400 lines)
- [PadelClub.Services/Recommendations/RecommendationEvaluationQualityPolicy.cs](../../PadelClub.Services/Recommendations/RecommendationEvaluationQualityPolicy.cs) (183 lines)
- [PadelClub.Services/Recommendations/RecommendationEvaluationService.cs](../../PadelClub.Services/Recommendations/RecommendationEvaluationService.cs) (503 lines)
- [PadelClub.Services/Recommendations/RecommendationExperimentPolicy.cs](../../PadelClub.Services/Recommendations/RecommendationExperimentPolicy.cs) (44 lines)
- [PadelClub.Services/Recommendations/RecommendationExperimentService.cs](../../PadelClub.Services/Recommendations/RecommendationExperimentService.cs) (699 lines)
- [PadelClub.Services/Recommendations/RecommendationImpactPolicy.cs](../../PadelClub.Services/Recommendations/RecommendationImpactPolicy.cs) (49 lines)
- [PadelClub.Services/Recommendations/RecommendationImpactService.cs](../../PadelClub.Services/Recommendations/RecommendationImpactService.cs) (152 lines)
- [PadelClub.Services/Recommendations/TemporalRecommendationEvaluator.cs](../../PadelClub.Services/Recommendations/TemporalRecommendationEvaluator.cs) (297 lines)
- [PadelClub.Services/ReservationService.cs](../../PadelClub.Services/ReservationService.cs) (297 lines)
- [PadelClub.Services/RoleService.cs](../../PadelClub.Services/RoleService.cs) (38 lines)
- [PadelClub.Services/ServiceCollectionExtensions.cs](../../PadelClub.Services/ServiceCollectionExtensions.cs) (52 lines)
- [PadelClub.Services/TournamentParticipantService.cs](../../PadelClub.Services/TournamentParticipantService.cs) (41 lines)
- [PadelClub.Services/TournamentService.cs](../../PadelClub.Services/TournamentService.cs) (54 lines)
- [PadelClub.Services/UserService.cs](../../PadelClub.Services/UserService.cs) (298 lines)
- [PadelClub.WebAPI/Auditing/AuditMiddleware.cs](../../PadelClub.WebAPI/Auditing/AuditMiddleware.cs) (32 lines)
- [PadelClub.WebAPI/Authentication/AuthOptions.cs](../../PadelClub.WebAPI/Authentication/AuthOptions.cs) (11 lines)
- [PadelClub.WebAPI/Authentication/AuthService.cs](../../PadelClub.WebAPI/Authentication/AuthService.cs) (150 lines)
- [PadelClub.WebAPI/Authentication/IAuthService.cs](../../PadelClub.WebAPI/Authentication/IAuthService.cs) (15 lines)
- [PadelClub.WebAPI/Authentication/ITransactionalEmailSender.cs](../../PadelClub.WebAPI/Authentication/ITransactionalEmailSender.cs) (30 lines)
- [PadelClub.WebAPI/Commerce/ReturnEligibilityPolicy.cs](../../PadelClub.WebAPI/Commerce/ReturnEligibilityPolicy.cs) (26 lines)
- [PadelClub.WebAPI/Controllers/BaseController.cs](../../PadelClub.WebAPI/Controllers/BaseController.cs) (33 lines)
- [PadelClub.WebAPI/Controllers/BaseCRUDController.cs](../../PadelClub.WebAPI/Controllers/BaseCRUDController.cs) (122 lines)
- [PadelClub.WebAPI/Controllers/ClubReviewsController.cs](../../PadelClub.WebAPI/Controllers/ClubReviewsController.cs) (40 lines)
- [PadelClub.WebAPI/Controllers/CommerceOperationsController.cs](../../PadelClub.WebAPI/Controllers/CommerceOperationsController.cs) (460 lines)
- [PadelClub.WebAPI/Controllers/CourtsController.cs](../../PadelClub.WebAPI/Controllers/CourtsController.cs) (30 lines)
- [PadelClub.WebAPI/Controllers/DiscoveryController.cs](../../PadelClub.WebAPI/Controllers/DiscoveryController.cs) (86 lines)
- [PadelClub.WebAPI/Controllers/MatchParticipantsController.cs](../../PadelClub.WebAPI/Controllers/MatchParticipantsController.cs) (17 lines)
- [PadelClub.WebAPI/Controllers/MembershipsController.cs](../../PadelClub.WebAPI/Controllers/MembershipsController.cs) (119 lines)
- [PadelClub.WebAPI/Controllers/NotificationsController.cs](../../PadelClub.WebAPI/Controllers/NotificationsController.cs) (70 lines)
- [PadelClub.WebAPI/Controllers/NotificationSettingsController.cs](../../PadelClub.WebAPI/Controllers/NotificationSettingsController.cs) (92 lines)
- [PadelClub.WebAPI/Controllers/OperationsController.cs](../../PadelClub.WebAPI/Controllers/OperationsController.cs) (177 lines)
- [PadelClub.WebAPI/Controllers/OrderItemsController.cs](../../PadelClub.WebAPI/Controllers/OrderItemsController.cs) (17 lines)
- [PadelClub.WebAPI/Controllers/OrdersController.cs](../../PadelClub.WebAPI/Controllers/OrdersController.cs) (63 lines)
- [PadelClub.WebAPI/Controllers/PaymentsController.cs](../../PadelClub.WebAPI/Controllers/PaymentsController.cs) (41 lines)
- [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs](../../PadelClub.WebAPI/Controllers/PlayerExperienceController.cs) (174 lines)
- [PadelClub.WebAPI/Controllers/PrivacyController.cs](../../PadelClub.WebAPI/Controllers/PrivacyController.cs) (94 lines)
- [PadelClub.WebAPI/Controllers/ProductCategoriesController.cs](../../PadelClub.WebAPI/Controllers/ProductCategoriesController.cs) (22 lines)
- [PadelClub.WebAPI/Controllers/ProductController.cs](../../PadelClub.WebAPI/Controllers/ProductController.cs) (44 lines)
- [PadelClub.WebAPI/Controllers/ProductTypesController.cs](../../PadelClub.WebAPI/Controllers/ProductTypesController.cs) (22 lines)
- [PadelClub.WebAPI/Controllers/ProviderReadinessController.cs](../../PadelClub.WebAPI/Controllers/ProviderReadinessController.cs) (137 lines)
- [PadelClub.WebAPI/Controllers/ProviderVerificationController.cs](../../PadelClub.WebAPI/Controllers/ProviderVerificationController.cs) (49 lines)
- [PadelClub.WebAPI/Controllers/RecommendationExperimentsController.cs](../../PadelClub.WebAPI/Controllers/RecommendationExperimentsController.cs) (106 lines)
- [PadelClub.WebAPI/Controllers/RecommendationImpactController.cs](../../PadelClub.WebAPI/Controllers/RecommendationImpactController.cs) (34 lines)
- [PadelClub.WebAPI/Controllers/RecommendationsController.cs](../../PadelClub.WebAPI/Controllers/RecommendationsController.cs) (77 lines)
- [PadelClub.WebAPI/Controllers/ReservationsController.cs](../../PadelClub.WebAPI/Controllers/ReservationsController.cs) (117 lines)
- [PadelClub.WebAPI/Controllers/RolesController.cs](../../PadelClub.WebAPI/Controllers/RolesController.cs) (30 lines)
- [PadelClub.WebAPI/Controllers/StripePaymentsController.cs](../../PadelClub.WebAPI/Controllers/StripePaymentsController.cs) (82 lines)
- [PadelClub.WebAPI/Controllers/TournamentController.cs](../../PadelClub.WebAPI/Controllers/TournamentController.cs) (22 lines)
- [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs](../../PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs) (135 lines)
- [PadelClub.WebAPI/Controllers/TournamentParticipantsController.cs](../../PadelClub.WebAPI/Controllers/TournamentParticipantsController.cs) (17 lines)
- [PadelClub.WebAPI/Controllers/UsersController.cs](../../PadelClub.WebAPI/Controllers/UsersController.cs) (142 lines)
- [PadelClub.WebAPI/Filters/ExceptionFilter.cs](../../PadelClub.WebAPI/Filters/ExceptionFilter.cs) (63 lines)
- [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs](../../PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs) (39 lines)
- [PadelClub.WebAPI/Monitoring/DatabaseHealthCheck.cs](../../PadelClub.WebAPI/Monitoring/DatabaseHealthCheck.cs) (19 lines)
- [PadelClub.WebAPI/Notifications/EmailSender.cs](../../PadelClub.WebAPI/Notifications/EmailSender.cs) (57 lines)
- [PadelClub.WebAPI/Notifications/NotificationDeliveryOptions.cs](../../PadelClub.WebAPI/Notifications/NotificationDeliveryOptions.cs) (23 lines)
- [PadelClub.WebAPI/Notifications/NotificationDeliveryWorker.cs](../../PadelClub.WebAPI/Notifications/NotificationDeliveryWorker.cs) (66 lines)
- [PadelClub.WebAPI/Notifications/PushSender.cs](../../PadelClub.WebAPI/Notifications/PushSender.cs) (55 lines)
- [PadelClub.WebAPI/Outbox/OutboxPublisherWorker.cs](../../PadelClub.WebAPI/Outbox/OutboxPublisherWorker.cs) (208 lines)
- [PadelClub.WebAPI/PadelClub.Subscriber/PadelClub.Subscriber.csproj](../../PadelClub.WebAPI/PadelClub.Subscriber/PadelClub.Subscriber.csproj) (33 lines)
- [PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs](../../PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs) (128 lines)
- [PadelClub.WebAPI/PadelClub.Subscriber/Program.cs](../../PadelClub.WebAPI/PadelClub.Subscriber/Program.cs) (21 lines)
- [PadelClub.WebAPI/PadelClub.WebAPI.csproj](../../PadelClub.WebAPI/PadelClub.WebAPI.csproj) (45 lines)
- [PadelClub.WebAPI/Payments/IProviderRefundOperationLeaseService.cs](../../PadelClub.WebAPI/Payments/IProviderRefundOperationLeaseService.cs) (34 lines)
- [PadelClub.WebAPI/Payments/IProviderRefundOperationProcessor.cs](../../PadelClub.WebAPI/Payments/IProviderRefundOperationProcessor.cs) (13 lines)
- [PadelClub.WebAPI/Payments/IProviderRefundOperationService.cs](../../PadelClub.WebAPI/Payments/IProviderRefundOperationService.cs) (31 lines)
- [PadelClub.WebAPI/Payments/IStripePaymentService.cs](../../PadelClub.WebAPI/Payments/IStripePaymentService.cs) (12 lines)
- [PadelClub.WebAPI/Payments/IStripeRefundGateway.cs](../../PadelClub.WebAPI/Payments/IStripeRefundGateway.cs) (20 lines)
- [PadelClub.WebAPI/Payments/ProviderRefundOperationProcessor.cs](../../PadelClub.WebAPI/Payments/ProviderRefundOperationProcessor.cs) (164 lines)
- [PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs](../../PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs) (199 lines)
- [PadelClub.WebAPI/Payments/ProviderRefundOperationStatuses.cs](../../PadelClub.WebAPI/Payments/ProviderRefundOperationStatuses.cs) (12 lines)
- [PadelClub.WebAPI/Payments/ProviderRefundOperationWorker.cs](../../PadelClub.WebAPI/Payments/ProviderRefundOperationWorker.cs) (98 lines)
- [PadelClub.WebAPI/Payments/SqlServerProviderRefundOperationLeaseService.cs](../../PadelClub.WebAPI/Payments/SqlServerProviderRefundOperationLeaseService.cs) (118 lines)
- [PadelClub.WebAPI/Payments/StripeOptions.cs](../../PadelClub.WebAPI/Payments/StripeOptions.cs) (9 lines)
- [PadelClub.WebAPI/Payments/StripePaymentService.cs](../../PadelClub.WebAPI/Payments/StripePaymentService.cs) (134 lines)
- [PadelClub.WebAPI/Payments/StripeRefundGateway.cs](../../PadelClub.WebAPI/Payments/StripeRefundGateway.cs) (93 lines)
- [PadelClub.WebAPI/PlayerExperience/MatchScoreValidator.cs](../../PadelClub.WebAPI/PlayerExperience/MatchScoreValidator.cs) (22 lines)
- [PadelClub.WebAPI/Privacy/PrivacyDeletionWorker.cs](../../PadelClub.WebAPI/Privacy/PrivacyDeletionWorker.cs) (47 lines)
- [PadelClub.WebAPI/Program.cs](../../PadelClub.WebAPI/Program.cs) (1199 lines)
- [PadelClub.WebAPI/Properties/AssemblyInfo.cs](../../PadelClub.WebAPI/Properties/AssemblyInfo.cs) (3 lines)
- [PadelClub.WebAPI/ProviderVerification/IProviderVerificationGateway.cs](../../PadelClub.WebAPI/ProviderVerification/IProviderVerificationGateway.cs) (24 lines)
- [PadelClub.WebAPI/ProviderVerification/IProviderVerificationService.cs](../../PadelClub.WebAPI/ProviderVerification/IProviderVerificationService.cs) (16 lines)
- [PadelClub.WebAPI/ProviderVerification/ProviderVerificationGateway.cs](../../PadelClub.WebAPI/ProviderVerification/ProviderVerificationGateway.cs) (59 lines)
- [PadelClub.WebAPI/ProviderVerification/ProviderVerificationOptions.cs](../../PadelClub.WebAPI/ProviderVerification/ProviderVerificationOptions.cs) (27 lines)
- [PadelClub.WebAPI/ProviderVerification/ProviderVerificationService.cs](../../PadelClub.WebAPI/ProviderVerification/ProviderVerificationService.cs) (230 lines)
- [PadelClub.WebAPI/Tournaments/BracketService.cs](../../PadelClub.WebAPI/Tournaments/BracketService.cs) (90 lines)
- [PadelClub.WebAPI.Tests/ApiIntegrationTests.cs](../../PadelClub.WebAPI.Tests/ApiIntegrationTests.cs) (1438 lines)
- [PadelClub.WebAPI.Tests/AuthorizationPolicyTests.cs](../../PadelClub.WebAPI.Tests/AuthorizationPolicyTests.cs) (44 lines)
- [PadelClub.WebAPI.Tests/AuthRequestValidationTests.cs](../../PadelClub.WebAPI.Tests/AuthRequestValidationTests.cs) (22 lines)
- [PadelClub.WebAPI.Tests/BookingConfigurationTests.cs](../../PadelClub.WebAPI.Tests/BookingConfigurationTests.cs) (22 lines)
- [PadelClub.WebAPI.Tests/CommerceOperationsTests.cs](../../PadelClub.WebAPI.Tests/CommerceOperationsTests.cs) (28 lines)
- [PadelClub.WebAPI.Tests/ExceptionFilterTests.cs](../../PadelClub.WebAPI.Tests/ExceptionFilterTests.cs) (27 lines)
- [PadelClub.WebAPI.Tests/Infrastructure/IntegrationDatabaseSeeder.cs](../../PadelClub.WebAPI.Tests/Infrastructure/IntegrationDatabaseSeeder.cs) (154 lines)
- [PadelClub.WebAPI.Tests/Infrastructure/PadelClubApiFactory.cs](../../PadelClub.WebAPI.Tests/Infrastructure/PadelClubApiFactory.cs) (73 lines)
- [PadelClub.WebAPI.Tests/Infrastructure/SqlServerIntegrationFixture.cs](../../PadelClub.WebAPI.Tests/Infrastructure/SqlServerIntegrationFixture.cs) (68 lines)
- [PadelClub.WebAPI.Tests/MessagingReliabilityTests.cs](../../PadelClub.WebAPI.Tests/MessagingReliabilityTests.cs) (130 lines)
- [PadelClub.WebAPI.Tests/NotificationDeliveryTests.cs](../../PadelClub.WebAPI.Tests/NotificationDeliveryTests.cs) (25 lines)
- [PadelClub.WebAPI.Tests/OutboxPublisherDeadlineTests.cs](../../PadelClub.WebAPI.Tests/OutboxPublisherDeadlineTests.cs) (55 lines)
- [PadelClub.WebAPI.Tests/PadelClub.WebAPI.Tests.csproj](../../PadelClub.WebAPI.Tests/PadelClub.WebAPI.Tests.csproj) (12 lines)
- [PadelClub.WebAPI.Tests/PasswordResetDeliveryTests.cs](../../PadelClub.WebAPI.Tests/PasswordResetDeliveryTests.cs) (37 lines)
- [PadelClub.WebAPI.Tests/PlayerExperienceTests.cs](../../PadelClub.WebAPI.Tests/PlayerExperienceTests.cs) (22 lines)
- [PadelClub.WebAPI.Tests/PopularityRecommendationRankerTests.cs](../../PadelClub.WebAPI.Tests/PopularityRecommendationRankerTests.cs) (115 lines)
- [PadelClub.WebAPI.Tests/ProductionReadinessTests.cs](../../PadelClub.WebAPI.Tests/ProductionReadinessTests.cs) (28 lines)
- [PadelClub.WebAPI.Tests/ProductRecommendationServiceTests.cs](../../PadelClub.WebAPI.Tests/ProductRecommendationServiceTests.cs) (328 lines)
- [PadelClub.WebAPI.Tests/ProductRecommendationTests.cs](../../PadelClub.WebAPI.Tests/ProductRecommendationTests.cs) (119 lines)
- [PadelClub.WebAPI.Tests/ProductUpdateStateTests.cs](../../PadelClub.WebAPI.Tests/ProductUpdateStateTests.cs) (132 lines)
- [PadelClub.WebAPI.Tests/ProspectiveEvidenceIntegrationTests.cs](../../PadelClub.WebAPI.Tests/ProspectiveEvidenceIntegrationTests.cs) (72 lines)
- [PadelClub.WebAPI.Tests/ProviderReadinessContractTests.cs](../../PadelClub.WebAPI.Tests/ProviderReadinessContractTests.cs) (124 lines)
- [PadelClub.WebAPI.Tests/ProviderRefundOperationIntegrationTests.cs](../../PadelClub.WebAPI.Tests/ProviderRefundOperationIntegrationTests.cs) (292 lines)
- [PadelClub.WebAPI.Tests/ProviderRefundOperationTests.cs](../../PadelClub.WebAPI.Tests/ProviderRefundOperationTests.cs) (188 lines)
- [PadelClub.WebAPI.Tests/ProviderVerificationServiceTests.cs](../../PadelClub.WebAPI.Tests/ProviderVerificationServiceTests.cs) (200 lines)
- [PadelClub.WebAPI.Tests/RecommendationCohortReadinessApiTests.cs](../../PadelClub.WebAPI.Tests/RecommendationCohortReadinessApiTests.cs) (55 lines)
- [PadelClub.WebAPI.Tests/RecommendationCohortReadinessTests.cs](../../PadelClub.WebAPI.Tests/RecommendationCohortReadinessTests.cs) (212 lines)
- [PadelClub.WebAPI.Tests/RecommendationEvaluationTests.cs](../../PadelClub.WebAPI.Tests/RecommendationEvaluationTests.cs) (396 lines)
- [PadelClub.WebAPI.Tests/RecommendationExperimentImpactTests.cs](../../PadelClub.WebAPI.Tests/RecommendationExperimentImpactTests.cs) (236 lines)
- [PadelClub.WebAPI.Tests/RecommendationExperimentServiceTests.cs](../../PadelClub.WebAPI.Tests/RecommendationExperimentServiceTests.cs) (114 lines)
- [PadelClub.WebAPI.Tests/RecommendationImpactTests.cs](../../PadelClub.WebAPI.Tests/RecommendationImpactTests.cs) (161 lines)
- [PadelClub.WebAPI.Tests/ReservationAvailabilityContractTests.cs](../../PadelClub.WebAPI.Tests/ReservationAvailabilityContractTests.cs) (94 lines)
- [PadelClub.WebAPI.Tests/StripeEndpointSecurityTests.cs](../../PadelClub.WebAPI.Tests/StripeEndpointSecurityTests.cs) (23 lines)
- [PadelClub.WebAPI.Tests/TournamentMembershipLifecycleTests.cs](../../PadelClub.WebAPI.Tests/TournamentMembershipLifecycleTests.cs) (27 lines)
- [scripts/backup-database.ps1](../../scripts/backup-database.ps1) (22 lines)
- [scripts/Invoke-CleanComposeSmoke.ps1](../../scripts/Invoke-CleanComposeSmoke.ps1) (634 lines)
- [scripts/Invoke-UciOnlineRetailBenchmark.ps1](../../scripts/Invoke-UciOnlineRetailBenchmark.ps1) (57 lines)
- [scripts/verify-backup.ps1](../../scripts/verify-backup.ps1) (18 lines)
- [tools/PadelClub.RecommendationBenchmark/PadelClub.RecommendationBenchmark.csproj](../../tools/PadelClub.RecommendationBenchmark/PadelClub.RecommendationBenchmark.csproj) (18 lines)
- [tools/PadelClub.RecommendationBenchmark/Program.cs](../../tools/PadelClub.RecommendationBenchmark/Program.cs) (935 lines)
- [UI/padelclub_desktop/analysis_options.yaml](../../UI/padelclub_desktop/analysis_options.yaml) (28 lines)
- [UI/padelclub_desktop/lib/core/di/injection.dart](../../UI/padelclub_desktop/lib/core/di/injection.dart) (273 lines)
- [UI/padelclub_desktop/lib/core/network/api_config.dart](../../UI/padelclub_desktop/lib/core/network/api_config.dart) (12 lines)
- [UI/padelclub_desktop/lib/core/theme/app_theme.dart](../../UI/padelclub_desktop/lib/core/theme/app_theme.dart) (218 lines)
- [UI/padelclub_desktop/lib/core/widgets/admin_components.dart](../../UI/padelclub_desktop/lib/core/widgets/admin_components.dart) (237 lines)
- [UI/padelclub_desktop/lib/dashboard_page.dart](../../UI/padelclub_desktop/lib/dashboard_page.dart) (1166 lines)
- [UI/padelclub_desktop/lib/features/coupons/data/coupon_management_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/coupons/data/coupon_management_remote_data_source.dart) (208 lines)
- [UI/padelclub_desktop/lib/features/coupons/domain/entities/admin_coupon.dart](../../UI/padelclub_desktop/lib/features/coupons/domain/entities/admin_coupon.dart) (130 lines)
- [UI/padelclub_desktop/lib/features/coupons/presentation/providers/coupon_management_provider.dart](../../UI/padelclub_desktop/lib/features/coupons/presentation/providers/coupon_management_provider.dart) (91 lines)
- [UI/padelclub_desktop/lib/features/coupons/presentation/screens/coupon_management_screen.dart](../../UI/padelclub_desktop/lib/features/coupons/presentation/screens/coupon_management_screen.dart) (813 lines)
- [UI/padelclub_desktop/lib/features/courts/data/models/court_model.dart](../../UI/padelclub_desktop/lib/features/courts/data/models/court_model.dart) (29 lines)
- [UI/padelclub_desktop/lib/features/courts/domain/entities/court.dart](../../UI/padelclub_desktop/lib/features/courts/domain/entities/court.dart) (21 lines)
- [UI/padelclub_desktop/lib/features/courts/presentation/providers/court_provider.dart](../../UI/padelclub_desktop/lib/features/courts/presentation/providers/court_provider.dart) (116 lines)
- [UI/padelclub_desktop/lib/features/courts/presentation/screens/court_management_screen.dart](../../UI/padelclub_desktop/lib/features/courts/presentation/screens/court_management_screen.dart) (547 lines)
- [UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart](../../UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart) (795 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart) (121 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/models/inventory_movement_model.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/models/inventory_movement_model.dart) (43 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart) (24 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/entities/inventory_movement.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/entities/inventory_movement.dart) (28 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/repositories/inventory_operations_repository.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/repositories/inventory_operations_repository.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/adjust_inventory.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/adjust_inventory.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/get_inventory_history.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/domain/usecases/get_inventory_history.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/inventory_operations/presentation/providers/inventory_operations_provider.dart](../../UI/padelclub_desktop/lib/features/inventory_operations/presentation/providers/inventory_operations_provider.dart) (96 lines)
- [UI/padelclub_desktop/lib/features/match_participants/data/datasources/match_participant_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/datasources/match_participant_remote_data_source.dart) (92 lines)
- [UI/padelclub_desktop/lib/features/match_participants/data/models/match_participant_model.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/models/match_participant_model.dart) (32 lines)
- [UI/padelclub_desktop/lib/features/match_participants/data/repositories/match_participant_repository_impl.dart](../../UI/padelclub_desktop/lib/features/match_participants/data/repositories/match_participant_repository_impl.dart) (16 lines)
- [UI/padelclub_desktop/lib/features/match_participants/domain/entities/match_participant.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/entities/match_participant.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/match_participants/domain/repositories/match_participant_repository.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/repositories/match_participant_repository.dart) (7 lines)
- [UI/padelclub_desktop/lib/features/match_participants/domain/usecases/get_match_participants.dart](../../UI/padelclub_desktop/lib/features/match_participants/domain/usecases/get_match_participants.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/match_participants/presentation/providers/match_participant_provider.dart](../../UI/padelclub_desktop/lib/features/match_participants/presentation/providers/match_participant_provider.dart) (93 lines)
- [UI/padelclub_desktop/lib/features/memberships/data/admin_membership_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/memberships/data/admin_membership_remote_data_source.dart) (233 lines)
- [UI/padelclub_desktop/lib/features/memberships/data/datasources/membership_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/memberships/data/datasources/membership_remote_data_source.dart) (166 lines)
- [UI/padelclub_desktop/lib/features/memberships/data/models/membership_event_model.dart](../../UI/padelclub_desktop/lib/features/memberships/data/models/membership_event_model.dart) (22 lines)
- [UI/padelclub_desktop/lib/features/memberships/data/models/membership_model.dart](../../UI/padelclub_desktop/lib/features/memberships/data/models/membership_model.dart) (66 lines)
- [UI/padelclub_desktop/lib/features/memberships/data/repositories/membership_repository_impl.dart](../../UI/padelclub_desktop/lib/features/memberships/data/repositories/membership_repository_impl.dart) (26 lines)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership.dart) (63 lines)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_event.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_event.dart) (15 lines)
- [UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_page.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/entities/membership_page.dart) (9 lines)
- [UI/padelclub_desktop/lib/features/memberships/domain/repositories/membership_repository.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/repositories/membership_repository.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/memberships/domain/usecases/get_memberships.dart](../../UI/padelclub_desktop/lib/features/memberships/domain/usecases/get_memberships.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_management_provider.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_management_provider.dart) (209 lines)
- [UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_provider.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/providers/membership_provider.dart) (154 lines)
- [UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_management_screen.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_management_screen.dart) (833 lines)
- [UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_self_service_screen.dart](../../UI/padelclub_desktop/lib/features/memberships/presentation/screens/membership_self_service_screen.dart) (668 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart) (71 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/data/models/notification_preferences_model.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/models/notification_preferences_model.dart) (29 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/data/repositories/notification_settings_repository_impl.dart](../../UI/padelclub_desktop/lib/features/notification_settings/data/repositories/notification_settings_repository_impl.dart) (27 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/entities/notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/entities/notification_preferences.dart) (28 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/repositories/notification_settings_repository.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/repositories/notification_settings_repository.dart) (7 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/get_notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/get_notification_preferences.dart) (10 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/save_notification_preferences.dart](../../UI/padelclub_desktop/lib/features/notification_settings/domain/usecases/save_notification_preferences.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/presentation/providers/notification_settings_provider.dart](../../UI/padelclub_desktop/lib/features/notification_settings/presentation/providers/notification_settings_provider.dart) (84 lines)
- [UI/padelclub_desktop/lib/features/notification_settings/presentation/screens/notification_settings_screen.dart](../../UI/padelclub_desktop/lib/features/notification_settings/presentation/screens/notification_settings_screen.dart) (274 lines)
- [UI/padelclub_desktop/lib/features/notifications/data/models/club_notification_model.dart](../../UI/padelclub_desktop/lib/features/notifications/data/models/club_notification_model.dart) (33 lines)
- [UI/padelclub_desktop/lib/features/notifications/data/notification_delivery_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/notifications/data/notification_delivery_remote_data_source.dart) (90 lines)
- [UI/padelclub_desktop/lib/features/notifications/domain/entities/club_notification.dart](../../UI/padelclub_desktop/lib/features/notifications/domain/entities/club_notification.dart) (27 lines)
- [UI/padelclub_desktop/lib/features/notifications/domain/entities/notification_delivery.dart](../../UI/padelclub_desktop/lib/features/notifications/domain/entities/notification_delivery.dart) (74 lines)
- [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart) (51 lines)
- [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart) (159 lines)
- [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_delivery_diagnostics_screen.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_delivery_diagnostics_screen.dart) (521 lines)
- [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart](../../UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart) (672 lines)
- [UI/padelclub_desktop/lib/features/operations/data/audit_trail_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/operations/data/audit_trail_remote_data_source.dart) (90 lines)
- [UI/padelclub_desktop/lib/features/operations/data/provider_readiness_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/operations/data/provider_readiness_remote_data_source.dart) (76 lines)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/audit_log_entry.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/audit_log_entry.dart) (66 lines)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/audit_trail_filter.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/audit_trail_filter.dart) (30 lines)
- [UI/padelclub_desktop/lib/features/operations/domain/entities/provider_readiness.dart](../../UI/padelclub_desktop/lib/features/operations/domain/entities/provider_readiness.dart) (80 lines)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/audit_trail_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/audit_trail_provider.dart) (45 lines)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/operations_analytics_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/operations_analytics_provider.dart) (81 lines)
- [UI/padelclub_desktop/lib/features/operations/presentation/providers/provider_readiness_provider.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/providers/provider_readiness_provider.dart) (38 lines)
- [UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart) (563 lines)
- [UI/padelclub_desktop/lib/features/operations/presentation/screens/provider_readiness_screen.dart](../../UI/padelclub_desktop/lib/features/operations/presentation/screens/provider_readiness_screen.dart) (461 lines)
- [UI/padelclub_desktop/lib/features/order_items/data/datasources/order_item_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/order_items/data/datasources/order_item_remote_data_source.dart) (89 lines)
- [UI/padelclub_desktop/lib/features/order_items/data/models/order_item_model.dart](../../UI/padelclub_desktop/lib/features/order_items/data/models/order_item_model.dart) (35 lines)
- [UI/padelclub_desktop/lib/features/order_items/data/repositories/order_item_repository_impl.dart](../../UI/padelclub_desktop/lib/features/order_items/data/repositories/order_item_repository_impl.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/order_items/domain/entities/order_item.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/entities/order_item.dart) (19 lines)
- [UI/padelclub_desktop/lib/features/order_items/domain/repositories/order_item_repository.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/repositories/order_item_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/order_items/domain/usecases/get_order_items.dart](../../UI/padelclub_desktop/lib/features/order_items/domain/usecases/get_order_items.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/order_items/presentation/providers/order_item_provider.dart](../../UI/padelclub_desktop/lib/features/order_items/presentation/providers/order_item_provider.dart) (94 lines)
- [UI/padelclub_desktop/lib/features/orders/data/datasources/order_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/orders/data/datasources/order_remote_data_source.dart) (87 lines)
- [UI/padelclub_desktop/lib/features/orders/data/models/order_model.dart](../../UI/padelclub_desktop/lib/features/orders/data/models/order_model.dart) (82 lines)
- [UI/padelclub_desktop/lib/features/orders/data/repositories/order_repository_impl.dart](../../UI/padelclub_desktop/lib/features/orders/data/repositories/order_repository_impl.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/orders/domain/entities/order.dart](../../UI/padelclub_desktop/lib/features/orders/domain/entities/order.dart) (29 lines)
- [UI/padelclub_desktop/lib/features/orders/domain/repositories/order_repository.dart](../../UI/padelclub_desktop/lib/features/orders/domain/repositories/order_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/orders/domain/usecases/get_orders.dart](../../UI/padelclub_desktop/lib/features/orders/domain/usecases/get_orders.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/orders/presentation/providers/order_provider.dart](../../UI/padelclub_desktop/lib/features/orders/presentation/providers/order_provider.dart) (264 lines)
- [UI/padelclub_desktop/lib/features/orders/presentation/screens/order_management_screen.dart](../../UI/padelclub_desktop/lib/features/orders/presentation/screens/order_management_screen.dart) (1146 lines)
- [UI/padelclub_desktop/lib/features/payment_history/data/payment_history_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/payment_history/data/payment_history_remote_data_source.dart) (110 lines)
- [UI/padelclub_desktop/lib/features/payment_history/domain/entities/payment_history_entry.dart](../../UI/padelclub_desktop/lib/features/payment_history/domain/entities/payment_history_entry.dart) (120 lines)
- [UI/padelclub_desktop/lib/features/payment_history/presentation/providers/payment_history_provider.dart](../../UI/padelclub_desktop/lib/features/payment_history/presentation/providers/payment_history_provider.dart) (43 lines)
- [UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart](../../UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart) (448 lines)
- [UI/padelclub_desktop/lib/features/payments/data/datasources/payment_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/payments/data/datasources/payment_remote_data_source.dart) (88 lines)
- [UI/padelclub_desktop/lib/features/payments/data/models/payment_model.dart](../../UI/padelclub_desktop/lib/features/payments/data/models/payment_model.dart) (26 lines)
- [UI/padelclub_desktop/lib/features/payments/data/repositories/payment_repository_impl.dart](../../UI/padelclub_desktop/lib/features/payments/data/repositories/payment_repository_impl.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/payments/domain/entities/payment.dart](../../UI/padelclub_desktop/lib/features/payments/domain/entities/payment.dart) (13 lines)
- [UI/padelclub_desktop/lib/features/payments/domain/repositories/payment_repository.dart](../../UI/padelclub_desktop/lib/features/payments/domain/repositories/payment_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/payments/domain/usecases/get_payments.dart](../../UI/padelclub_desktop/lib/features/payments/domain/usecases/get_payments.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/payments/presentation/providers/payment_provider.dart](../../UI/padelclub_desktop/lib/features/payments/presentation/providers/payment_provider.dart) (92 lines)
- [UI/padelclub_desktop/lib/features/player_experience/presentation/providers/player_experience_provider.dart](../../UI/padelclub_desktop/lib/features/player_experience/presentation/providers/player_experience_provider.dart) (563 lines)
- [UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart](../../UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart) (1010 lines)
- [UI/padelclub_desktop/lib/features/privacy/data/datasources/privacy_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/privacy/data/datasources/privacy_remote_data_source.dart) (105 lines)
- [UI/padelclub_desktop/lib/features/privacy/data/models/privacy_deletion_status_model.dart](../../UI/padelclub_desktop/lib/features/privacy/data/models/privacy_deletion_status_model.dart) (47 lines)
- [UI/padelclub_desktop/lib/features/privacy/data/repositories/privacy_repository_impl.dart](../../UI/padelclub_desktop/lib/features/privacy/data/repositories/privacy_repository_impl.dart) (25 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/entities/privacy_deletion_status.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/entities/privacy_deletion_status.dart) (40 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/repositories/privacy_repository.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/repositories/privacy_repository.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/cancel_account_deletion.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/cancel_account_deletion.dart) (9 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_account_deletion_status.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_account_deletion_status.dart) (10 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_privacy_export.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/get_privacy_export.dart) (9 lines)
- [UI/padelclub_desktop/lib/features/privacy/domain/usecases/request_account_deletion.dart](../../UI/padelclub_desktop/lib/features/privacy/domain/usecases/request_account_deletion.dart) (10 lines)
- [UI/padelclub_desktop/lib/features/privacy/presentation/providers/privacy_controls_provider.dart](../../UI/padelclub_desktop/lib/features/privacy/presentation/providers/privacy_controls_provider.dart) (129 lines)
- [UI/padelclub_desktop/lib/features/privacy/presentation/screens/privacy_controls_screen.dart](../../UI/padelclub_desktop/lib/features/privacy/presentation/screens/privacy_controls_screen.dart) (532 lines)
- [UI/padelclub_desktop/lib/features/product/data/datasources/product_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product/data/datasources/product_remote_data_source.dart) (96 lines)
- [UI/padelclub_desktop/lib/features/product/data/models/product_model.dart](../../UI/padelclub_desktop/lib/features/product/data/models/product_model.dart) (36 lines)
- [UI/padelclub_desktop/lib/features/product/data/models/search_result.dart](../../UI/padelclub_desktop/lib/features/product/data/models/search_result.dart) (6 lines)
- [UI/padelclub_desktop/lib/features/product/data/repositories/product_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product/data/repositories/product_repository_impl.dart) (15 lines)
- [UI/padelclub_desktop/lib/features/product/domain/entities/product.dart](../../UI/padelclub_desktop/lib/features/product/domain/entities/product.dart) (29 lines)
- [UI/padelclub_desktop/lib/features/product/domain/entities/product.g.dart](../../UI/padelclub_desktop/lib/features/product/domain/entities/product.g.dart) (27 lines)
- [UI/padelclub_desktop/lib/features/product/domain/repositories/product_repository.dart](../../UI/padelclub_desktop/lib/features/product/domain/repositories/product_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/product/domain/usecases/get_products.dart](../../UI/padelclub_desktop/lib/features/product/domain/usecases/get_products.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart) (141 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/logged_product_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/logged_product_provider.dart) (35 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/providers/product_provider.dart](../../UI/padelclub_desktop/lib/features/product/presentation/providers/product_provider.dart) (86 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_details_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_details_screen.dart) (192 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_list_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_list_screen.dart) (1882 lines)
- [UI/padelclub_desktop/lib/features/product/presentation/screens/product_management_screen.dart](../../UI/padelclub_desktop/lib/features/product/presentation/screens/product_management_screen.dart) (659 lines)
- [UI/padelclub_desktop/lib/features/product_categories/data/datasources/product_category_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/datasources/product_category_remote_data_source.dart) (92 lines)
- [UI/padelclub_desktop/lib/features/product_categories/data/models/product_category_model.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/models/product_category_model.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/product_categories/data/repositories/product_category_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product_categories/data/repositories/product_category_repository_impl.dart) (16 lines)
- [UI/padelclub_desktop/lib/features/product_categories/domain/entities/product_category.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/entities/product_category.dart) (6 lines)
- [UI/padelclub_desktop/lib/features/product_categories/domain/repositories/product_category_repository.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/repositories/product_category_repository.dart) (7 lines)
- [UI/padelclub_desktop/lib/features/product_categories/domain/usecases/get_product_categories.dart](../../UI/padelclub_desktop/lib/features/product_categories/domain/usecases/get_product_categories.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/product_categories/presentation/providers/product_category_provider.dart](../../UI/padelclub_desktop/lib/features/product_categories/presentation/providers/product_category_provider.dart) (82 lines)
- [UI/padelclub_desktop/lib/features/product_types/data/datasources/product_type_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/product_types/data/datasources/product_type_remote_data_source.dart) (91 lines)
- [UI/padelclub_desktop/lib/features/product_types/data/models/product_type_model.dart](../../UI/padelclub_desktop/lib/features/product_types/data/models/product_type_model.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/product_types/data/repositories/product_type_repository_impl.dart](../../UI/padelclub_desktop/lib/features/product_types/data/repositories/product_type_repository_impl.dart) (16 lines)
- [UI/padelclub_desktop/lib/features/product_types/domain/entities/product_type.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/entities/product_type.dart) (6 lines)
- [UI/padelclub_desktop/lib/features/product_types/domain/repositories/product_type_repository.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/repositories/product_type_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/product_types/domain/usecases/get_product_types.dart](../../UI/padelclub_desktop/lib/features/product_types/domain/usecases/get_product_types.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/product_types/presentation/providers/product_type_provider.dart](../../UI/padelclub_desktop/lib/features/product_types/presentation/providers/product_type_provider.dart) (82 lines)
- [UI/padelclub_desktop/lib/features/profile/presentation/screens/profile_screen.dart](../../UI/padelclub_desktop/lib/features/profile/presentation/screens/profile_screen.dart) (803 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart) (132 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart) (557 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/data/repositories/recommendation_evaluation_repository_impl.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/data/repositories/recommendation_evaluation_repository_impl.dart) (41 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart) (192 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart) (20 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart) (20 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart) (139 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart) (180 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_evaluation_evidence_panel.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_evaluation_evidence_panel.dart) (709 lines)
- [UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_operational_readiness_panel.dart](../../UI/padelclub_desktop/lib/features/recommendation_evaluation/presentation/widgets/recommendation_operational_readiness_panel.dart) (316 lines)
- [UI/padelclub_desktop/lib/features/recommendations/domain/entities/product_recommendation.dart](../../UI/padelclub_desktop/lib/features/recommendations/domain/entities/product_recommendation.dart) (44 lines)
- [UI/padelclub_desktop/lib/features/recommendations/presentation/providers/product_recommendation_provider.dart](../../UI/padelclub_desktop/lib/features/recommendations/presentation/providers/product_recommendation_provider.dart) (75 lines)
- [UI/padelclub_desktop/lib/features/reservations/data/datasources/reservation_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/reservations/data/datasources/reservation_remote_data_source.dart) (91 lines)
- [UI/padelclub_desktop/lib/features/reservations/data/models/reservation_model.dart](../../UI/padelclub_desktop/lib/features/reservations/data/models/reservation_model.dart) (38 lines)
- [UI/padelclub_desktop/lib/features/reservations/data/repositories/reservation_repository_impl.dart](../../UI/padelclub_desktop/lib/features/reservations/data/repositories/reservation_repository_impl.dart) (16 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/account_credit.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/account_credit.dart) (19 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/court_availability.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/court_availability.dart) (33 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/reservation.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/reservation.dart) (21 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/entities/waitlist_entry.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/entities/waitlist_entry.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/repositories/reservation_repository.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/repositories/reservation_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/reservations/domain/usecases/get_reservations.dart](../../UI/padelclub_desktop/lib/features/reservations/domain/usecases/get_reservations.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/reservations/presentation/providers/reservation_provider.dart](../../UI/padelclub_desktop/lib/features/reservations/presentation/providers/reservation_provider.dart) (303 lines)
- [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart](../../UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart) (1812 lines)
- [UI/padelclub_desktop/lib/features/returns/data/datasources/return_requests_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/returns/data/datasources/return_requests_remote_data_source.dart) (215 lines)
- [UI/padelclub_desktop/lib/features/returns/data/models/return_eligible_order_model.dart](../../UI/padelclub_desktop/lib/features/returns/data/models/return_eligible_order_model.dart) (82 lines)
- [UI/padelclub_desktop/lib/features/returns/data/models/return_request_status_model.dart](../../UI/padelclub_desktop/lib/features/returns/data/models/return_request_status_model.dart) (76 lines)
- [UI/padelclub_desktop/lib/features/returns/data/repositories/return_requests_repository_impl.dart](../../UI/padelclub_desktop/lib/features/returns/data/repositories/return_requests_repository_impl.dart) (44 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/entities/return_eligible_order.dart](../../UI/padelclub_desktop/lib/features/returns/domain/entities/return_eligible_order.dart) (51 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/entities/return_request_status.dart](../../UI/padelclub_desktop/lib/features/returns/domain/entities/return_request_status.dart) (40 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/repositories/return_requests_repository.dart](../../UI/padelclub_desktop/lib/features/returns/domain/repositories/return_requests_repository.dart) (23 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/create_return_request.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/create_return_request.dart) (20 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_eligible_return_orders.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_eligible_return_orders.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_my_return_requests.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_my_return_requests.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/get_return_requests.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/get_return_requests.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/returns/domain/usecases/resolve_return_request.dart](../../UI/padelclub_desktop/lib/features/returns/domain/usecases/resolve_return_request.dart) (18 lines)
- [UI/padelclub_desktop/lib/features/returns/presentation/providers/return_requests_provider.dart](../../UI/padelclub_desktop/lib/features/returns/presentation/providers/return_requests_provider.dart) (212 lines)
- [UI/padelclub_desktop/lib/features/reviews/data/models/club_review_model.dart](../../UI/padelclub_desktop/lib/features/reviews/data/models/club_review_model.dart) (23 lines)
- [UI/padelclub_desktop/lib/features/reviews/domain/entities/club_review.dart](../../UI/padelclub_desktop/lib/features/reviews/domain/entities/club_review.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/reviews/presentation/providers/club_review_provider.dart](../../UI/padelclub_desktop/lib/features/reviews/presentation/providers/club_review_provider.dart) (72 lines)
- [UI/padelclub_desktop/lib/features/roles/data/datasources/role_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/roles/data/datasources/role_remote_data_source.dart) (87 lines)
- [UI/padelclub_desktop/lib/features/roles/data/models/role_model.dart](../../UI/padelclub_desktop/lib/features/roles/data/models/role_model.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/roles/data/repositories/role_repository_impl.dart](../../UI/padelclub_desktop/lib/features/roles/data/repositories/role_repository_impl.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/roles/domain/entities/role.dart](../../UI/padelclub_desktop/lib/features/roles/domain/entities/role.dart) (6 lines)
- [UI/padelclub_desktop/lib/features/roles/domain/repositories/role_repository.dart](../../UI/padelclub_desktop/lib/features/roles/domain/repositories/role_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/roles/domain/usecases/get_roles.dart](../../UI/padelclub_desktop/lib/features/roles/domain/usecases/get_roles.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/roles/presentation/providers/role_provider.dart](../../UI/padelclub_desktop/lib/features/roles/presentation/providers/role_provider.dart) (82 lines)
- [UI/padelclub_desktop/lib/features/search/data/models/discovery_models.dart](../../UI/padelclub_desktop/lib/features/search/data/models/discovery_models.dart) (48 lines)
- [UI/padelclub_desktop/lib/features/search/domain/entities/discovery_match.dart](../../UI/padelclub_desktop/lib/features/search/domain/entities/discovery_match.dart) (21 lines)
- [UI/padelclub_desktop/lib/features/search/domain/entities/player_ranking.dart](../../UI/padelclub_desktop/lib/features/search/domain/entities/player_ranking.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/search/presentation/providers/discovery_provider.dart](../../UI/padelclub_desktop/lib/features/search/presentation/providers/discovery_provider.dart) (61 lines)
- [UI/padelclub_desktop/lib/features/search/presentation/screens/search_screen.dart](../../UI/padelclub_desktop/lib/features/search/presentation/screens/search_screen.dart) (680 lines)
- [UI/padelclub_desktop/lib/features/tournament/data/datasources/tournament_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament/data/datasources/tournament_remote_data_source.dart) (87 lines)
- [UI/padelclub_desktop/lib/features/tournament/data/models/tournament_model.dart](../../UI/padelclub_desktop/lib/features/tournament/data/models/tournament_model.dart) (46 lines)
- [UI/padelclub_desktop/lib/features/tournament/data/repositories/tournament_repository_impl.dart](../../UI/padelclub_desktop/lib/features/tournament/data/repositories/tournament_repository_impl.dart) (16 lines)
- [UI/padelclub_desktop/lib/features/tournament/domain/entities/tournament.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/entities/tournament.dart) (25 lines)
- [UI/padelclub_desktop/lib/features/tournament/domain/repositories/tournament_repository.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/repositories/tournament_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/tournament/domain/usecases/get_tournaments.dart](../../UI/padelclub_desktop/lib/features/tournament/domain/usecases/get_tournaments.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/tournament/presentation/providers/tournament_provider.dart](../../UI/padelclub_desktop/lib/features/tournament/presentation/providers/tournament_provider.dart) (57 lines)
- [UI/padelclub_desktop/lib/features/tournament_management/data/tournament_management_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament_management/data/tournament_management_remote_data_source.dart) (183 lines)
- [UI/padelclub_desktop/lib/features/tournament_management/domain/entities/tournament_draft.dart](../../UI/padelclub_desktop/lib/features/tournament_management/domain/entities/tournament_draft.dart) (47 lines)
- [UI/padelclub_desktop/lib/features/tournament_management/presentation/providers/tournament_management_provider.dart](../../UI/padelclub_desktop/lib/features/tournament_management/presentation/providers/tournament_management_provider.dart) (115 lines)
- [UI/padelclub_desktop/lib/features/tournament_management/presentation/screens/tournament_management_screen.dart](../../UI/padelclub_desktop/lib/features/tournament_management/presentation/screens/tournament_management_screen.dart) (863 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart) (96 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/models/tournament_participant_model.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/models/tournament_participant_model.dart) (23 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/data/repositories/tournament_participant_repository_impl.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/data/repositories/tournament_participant_repository_impl.dart) (17 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/entities/tournament_participant.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/entities/tournament_participant.dart) (11 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/repositories/tournament_participant_repository.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/repositories/tournament_participant_repository.dart) (7 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/domain/usecases/get_tournament_participants.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/domain/usecases/get_tournament_participants.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/tournament_participants/presentation/providers/tournament_participant_provider.dart](../../UI/padelclub_desktop/lib/features/tournament_participants/presentation/providers/tournament_participant_provider.dart) (95 lines)
- [UI/padelclub_desktop/lib/features/users/data/datasources/user_remote_data_source.dart](../../UI/padelclub_desktop/lib/features/users/data/datasources/user_remote_data_source.dart) (87 lines)
- [UI/padelclub_desktop/lib/features/users/data/models/user_model.dart](../../UI/padelclub_desktop/lib/features/users/data/models/user_model.dart) (44 lines)
- [UI/padelclub_desktop/lib/features/users/data/repositories/user_repository_impl.dart](../../UI/padelclub_desktop/lib/features/users/data/repositories/user_repository_impl.dart) (14 lines)
- [UI/padelclub_desktop/lib/features/users/domain/entities/user.dart](../../UI/padelclub_desktop/lib/features/users/domain/entities/user.dart) (26 lines)
- [UI/padelclub_desktop/lib/features/users/domain/repositories/user_repository.dart](../../UI/padelclub_desktop/lib/features/users/domain/repositories/user_repository.dart) (5 lines)
- [UI/padelclub_desktop/lib/features/users/domain/usecases/get_users.dart](../../UI/padelclub_desktop/lib/features/users/domain/usecases/get_users.dart) (12 lines)
- [UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart](../../UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart) (57 lines)
- [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart](../../UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart) (377 lines)
- [UI/padelclub_desktop/lib/layouts/master_screen.dart](../../UI/padelclub_desktop/lib/layouts/master_screen.dart) (323 lines)
- [UI/padelclub_desktop/lib/main.dart](../../UI/padelclub_desktop/lib/main.dart) (747 lines)
- [UI/padelclub_desktop/lib/providers/auth_provider.dart](../../UI/padelclub_desktop/lib/providers/auth_provider.dart) (317 lines)
- [UI/padelclub_desktop/lib/screens/product_details_screen.dart](../../UI/padelclub_desktop/lib/screens/product_details_screen.dart) (150 lines)
- [UI/padelclub_desktop/pubspec.yaml](../../UI/padelclub_desktop/pubspec.yaml) (96 lines)
- [UI/padelclub_desktop/test/audit_trail_test.dart](../../UI/padelclub_desktop/test/audit_trail_test.dart) (127 lines)
- [UI/padelclub_desktop/test/cart_provider_test.dart](../../UI/padelclub_desktop/test/cart_provider_test.dart) (82 lines)
- [UI/padelclub_desktop/test/coupon_management_provider_test.dart](../../UI/padelclub_desktop/test/coupon_management_provider_test.dart) (129 lines)
- [UI/padelclub_desktop/test/inventory_operations_provider_test.dart](../../UI/padelclub_desktop/test/inventory_operations_provider_test.dart) (67 lines)
- [UI/padelclub_desktop/test/membership_management_provider_test.dart](../../UI/padelclub_desktop/test/membership_management_provider_test.dart) (167 lines)
- [UI/padelclub_desktop/test/membership_provider_test.dart](../../UI/padelclub_desktop/test/membership_provider_test.dart) (191 lines)
- [UI/padelclub_desktop/test/notification_delivery_diagnostics_test.dart](../../UI/padelclub_desktop/test/notification_delivery_diagnostics_test.dart) (135 lines)
- [UI/padelclub_desktop/test/notification_settings_provider_test.dart](../../UI/padelclub_desktop/test/notification_settings_provider_test.dart) (60 lines)
- [UI/padelclub_desktop/test/notification_settings_remote_data_source_test.dart](../../UI/padelclub_desktop/test/notification_settings_remote_data_source_test.dart) (63 lines)
- [UI/padelclub_desktop/test/operations_analytics_test.dart](../../UI/padelclub_desktop/test/operations_analytics_test.dart) (22 lines)
- [UI/padelclub_desktop/test/order_fulfillment_test.dart](../../UI/padelclub_desktop/test/order_fulfillment_test.dart) (242 lines)
- [UI/padelclub_desktop/test/order_return_resolution_screen_test.dart](../../UI/padelclub_desktop/test/order_return_resolution_screen_test.dart) (139 lines)
- [UI/padelclub_desktop/test/payment_history_test.dart](../../UI/padelclub_desktop/test/payment_history_test.dart) (148 lines)
- [UI/padelclub_desktop/test/player_experience_provider_test.dart](../../UI/padelclub_desktop/test/player_experience_provider_test.dart) (155 lines)
- [UI/padelclub_desktop/test/privacy_controls_provider_test.dart](../../UI/padelclub_desktop/test/privacy_controls_provider_test.dart) (72 lines)
- [UI/padelclub_desktop/test/provider_readiness_test.dart](../../UI/padelclub_desktop/test/provider_readiness_test.dart) (85 lines)
- [UI/padelclub_desktop/test/recommendation_evaluation_test.dart](../../UI/padelclub_desktop/test/recommendation_evaluation_test.dart) (467 lines)
- [UI/padelclub_desktop/test/recommendation_operational_readiness_provider_test.dart](../../UI/padelclub_desktop/test/recommendation_operational_readiness_provider_test.dart) (76 lines)
- [UI/padelclub_desktop/test/reservation_admin_operations_test.dart](../../UI/padelclub_desktop/test/reservation_admin_operations_test.dart) (150 lines)
- [UI/padelclub_desktop/test/reservation_booking_activity_test.dart](../../UI/padelclub_desktop/test/reservation_booking_activity_test.dart) (118 lines)
- [UI/padelclub_desktop/test/return_requests_provider_test.dart](../../UI/padelclub_desktop/test/return_requests_provider_test.dart) (155 lines)
- [UI/padelclub_desktop/test/tournament_management_test.dart](../../UI/padelclub_desktop/test/tournament_management_test.dart) (216 lines)
- [UI/padelclub_desktop/test/widget_test.dart](../../UI/padelclub_desktop/test/widget_test.dart) (247 lines)
- [UI/padelclub_mobile/analysis_options.yaml](../../UI/padelclub_mobile/analysis_options.yaml) (28 lines)
- [UI/padelclub_mobile/lib/main.dart](../../UI/padelclub_mobile/lib/main.dart) (25 lines)
- [UI/padelclub_mobile/pubspec.yaml](../../UI/padelclub_mobile/pubspec.yaml) (21 lines)
- [UI/padelclub_mobile/test/mobile_bootstrap_test.dart](../../UI/padelclub_mobile/test/mobile_bootstrap_test.dart) (57 lines)
