using System;
using PadelClub.Model.Responses;

namespace PadelClub.Model.Messages
{
    public class ProductUpdated
    {
        /// <summary>
        /// The durable outbox message identifier. Consumers must treat this as
        /// an idempotency key because broker publication is at-least-once.
        /// </summary>
        public Guid EventId { get; set; }

        public ProductResponse Product { get; set; } = new();
    }
}
