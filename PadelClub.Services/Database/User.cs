using System;
using System.Collections.Generic;

namespace PadelClub.Services.Database
{
    public class User
    {
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

        // Navigation properties
        public virtual ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
        public virtual ICollection<Membership> Memberships { get; set; } = new List<Membership>();
        public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();
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
        public virtual ICollection<PushDevice> PushDevices { get; set; } = new List<PushDevice>();
        public virtual ICollection<NotificationDelivery> NotificationDeliveries { get; set; } = new List<NotificationDelivery>();
        public virtual PlayerProfile? PlayerProfile { get; set; }
        public virtual ICollection<PartnerInvitation> SentPartnerInvitations { get; set; } = new List<PartnerInvitation>();
        public virtual ICollection<PartnerInvitation> ReceivedPartnerInvitations { get; set; } = new List<PartnerInvitation>();
        public virtual ICollection<PrivacyRequest> PrivacyRequests { get; set; } = new List<PrivacyRequest>();
    }
}


