using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses;

/// <summary>
/// A caller-owned delivered order that still has at least one line available
/// for a new customer return request.
/// </summary>
public sealed class EligibleReturnOrderResponse
{
    public int OrderId { get; init; }

    public string OrderNumber { get; init; } = string.Empty;

    public DateTime DeliveredAt { get; init; }

    public DateTime ReturnWindowEndsAt { get; init; }

    public IReadOnlyList<EligibleReturnOrderItemResponse> Items { get; init; } =
        Array.Empty<EligibleReturnOrderItemResponse>();
}

/// <summary>
/// A safe, customer-facing returnable order line. It contains no unrelated
/// order, payment, address, or user information.
/// </summary>
public sealed class EligibleReturnOrderItemResponse
{
    public int OrderItemId { get; init; }

    public string ProductName { get; init; } = string.Empty;

    public int Quantity { get; init; }

    public int RemainingReturnableQuantity { get; init; }

    public decimal UnitPrice { get; init; }

    public decimal LineTotal { get; init; }
}
