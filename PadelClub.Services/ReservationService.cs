using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MapsterMapper;
using PadelClub.Model.Responses;
using System.Data;
using System.Globalization;
using Microsoft.Extensions.Options;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public class ReservationService : BaseCRUDService<ReservationResponse, ReservationSearchObject, Reservation, ReservationInsertRequest, ReservationUpdateRequest>, IReservationService
    {
        private readonly INotificationService _notificationService;
        private readonly BookingOptions _options;
        private readonly ICourtScheduleService _schedule;
        private readonly TimeZoneInfo _timeZone;

        public ReservationService(PadelClubContext dbContext, IMapper mapper, INotificationService notificationService, IOptions<BookingOptions> options, ICourtScheduleService? schedule = null) : base(dbContext, mapper)
        {
            _notificationService = notificationService;
            _schedule = schedule ?? new CourtScheduleService(dbContext);
            _options = options.Value;
            _timeZone = TimeZoneInfo.FindSystemTimeZoneById(_options.TimeZoneId);
        }

        protected override IQueryable<Reservation> ApplyFilter(IQueryable<Reservation> query, ReservationSearchObject search)
        {
            if (search.CourtId.HasValue)    
            {
                query = query.Where(r => r.CourtId == search.CourtId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(r => r.UserId == search.UserId.Value);
            }


            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                query = query.Where(r => r.Status.Contains(search.Status));
            }

            if (search.StartTimeFrom.HasValue)
            {
                query = query.Where(r => r.StartTime >= search.StartTimeFrom.Value);
            }

            if (search.StartTimeTo.HasValue)
            {
                query = query.Where(r => r.StartTime <= search.StartTimeTo.Value);
            }

            if (search.EndTimeFrom.HasValue)
            {
                query = query.Where(r => r.EndTime >= search.EndTimeFrom.Value);
            }

            if (search.EndTimeTo.HasValue)
            {
                query = query.Where(r => r.EndTime <= search.EndTimeTo.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(r => 
                    r.Status.Contains(search.FTS) ||
                    (r.Notes != null && r.Notes.Contains(search.FTS)));
            }

            return base.ApplyFilter(query.Include(x => x.Court).Include(x => x.User), search);
        }

        public override async Task<ReservationResponse> CreateAsync(ReservationInsertRequest request)
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);

            await _schedule.LockCourtsAsync(request.CourtId);
            await ValidateReservationAsync(request.CourtId, request.UserId, request.StartTime, request.EndTime);
            var court = await _dbContext.Courts.SingleAsync(x => x.Id == request.CourtId);
            var durationHours = (decimal)(request.EndTime - request.StartTime).TotalHours;

            var entity = new Reservation
            {
                CourtId = request.CourtId,
                UserId = request.UserId,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                TotalPrice = decimal.Round(court.HourlyRate * durationHours, 2),
                Status = "Confirmed",
                Notes = request.Notes?.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            _dbContext.Reservations.Add(entity);
            await _dbContext.SaveChangesAsync();
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Reservation confirmed",
                Message = $"Your reservation for {court.Name} on {FormatClubTime(entity.StartTime)} is confirmed.",
                Type = "Bookings",
                RecipientUserIds = new List<int> { entity.UserId }
            });
            await transaction.CommitAsync();
            return _mapper.Map<ReservationResponse>(entity);
        }

        public async Task<ReservationResponse?> GetOwnedByIdAsync(int id, int userId, bool isAdministrator)
        {
            var entity = await _dbContext.Reservations.AsNoTracking().Include(x => x.Court).Include(x => x.User)
                .SingleOrDefaultAsync(x => x.Id == id && (isAdministrator || x.UserId == userId));
            return entity is null ? null : MapToResponse(entity);
        }

        protected override ReservationResponse MapToResponse(Reservation entity)
        {
            var response = base.MapToResponse(entity);
            response.CourtName = entity.Court?.Name ?? string.Empty;
            response.UserName = entity.User is null ? string.Empty : (entity.User.FirstName + " " + entity.User.LastName).Trim();
            return response;
        }

        public override Task<bool> DeleteAsync(int id) =>
            throw new InvalidOperationException("Reservation history cannot be deleted. Use the cancellation workflow.");

        public override async Task<ReservationResponse?> UpdateAsync(int id, ReservationUpdateRequest request)
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await _schedule.LockCourtsAsync();
            var entity = await LockedReservationAsync(id);
            if (entity is null) return null;
            if (request.Status != entity.Status || entity.Status is not ("Pending" or "Confirmed"))
                throw new InvalidOperationException("Use a reservation lifecycle action to change status; terminal reservations cannot be edited.");
            if (request.UserId != entity.UserId)
                throw new InvalidOperationException("A reservation cannot be transferred to another user.");
            if (await _dbContext.Payments.AnyAsync(x => x.ReservationId == id))
                throw new InvalidOperationException("A reservation with a payment cannot be edited. Use the cancellation workflow.");
            await ValidateReservationAsync(request.CourtId, entity.UserId, request.StartTime, request.EndTime, entity.Id);
            var court = await _dbContext.Courts.SingleAsync(x => x.Id == request.CourtId);
            entity.CourtId = request.CourtId;
            entity.StartTime = request.StartTime;
            entity.EndTime = request.EndTime;
            entity.Notes = request.Notes?.Trim();
            entity.TotalPrice = decimal.Round(court.HourlyRate * (decimal)(request.EndTime - request.StartTime).TotalHours, 2);
            entity.UpdatedAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();
            return _mapper.Map<ReservationResponse>(entity);
        }

        private Task<Reservation?> LockedReservationAsync(int id) =>
            (_dbContext.Database.IsSqlServer()
                ? _dbContext.Reservations.FromSqlInterpolated($"SELECT * FROM [Reservations] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {id}")
                : _dbContext.Reservations.Where(x => x.Id == id)).SingleOrDefaultAsync();

        public async Task<List<CourtAvailabilityResponse>> GetAvailabilityAsync(DateTime date)
        {
            var localDate = DateTime.SpecifyKind(date.Date, DateTimeKind.Unspecified);
            var dayStart = TimeZoneInfo.ConvertTimeToUtc(localDate.AddHours(_options.OpeningHour), _timeZone);
            var dayEnd = TimeZoneInfo.ConvertTimeToUtc(localDate.AddHours(_options.ClosingHour), _timeZone);
            var courts = await _dbContext.Courts.Where(x => x.IsActive).OrderBy(x => x.Name).ToListAsync();
            var occupations = await _schedule.GetOccupationsAsync(dayStart, dayEnd);
            var now = DateTime.UtcNow;

            return courts.Select(court => new CourtAvailabilityResponse
            {
                CourtId = court.Id,
                CourtName = court.Name,
                IsIndoor = court.IsIndoor,
                MaxPlayers = court.MaxPlayers,
                HourlyRate = court.HourlyRate,
                Slots = Enumerable.Range(0, (int)((dayEnd - dayStart).TotalMinutes / _options.SlotMinutes)).Select(index =>
                {
                    var start = dayStart.AddMinutes(index * _options.SlotMinutes);
                    var end = start.AddMinutes(_options.SlotMinutes);
                    var isReserved = occupations.Any(x => x.Kind == "reservation" && x.Overlaps(court.Id, start, end));
                    var isBlocked = occupations.Any(x => x.Overlaps(court.Id, start, end));
                    return new AvailabilitySlotResponse
                    {
                        StartTime = start,
                        EndTime = end,
                        Price = court.HourlyRate,
                        IsAvailable = start > now && !isBlocked,
                        IsWaitlistEligible = start > now && isReserved
                    };
                }).ToList()
            }).ToList();
        }

        public Task<PagedResult<ReservationResponse>> GetForUserAsync(int userId, ReservationSearchObject search)
        {
            search.UserId = userId;
            return GetAsync(search);
        }

        public async Task<ReservationResponse?> CancelAsync(int id, int userId, bool isAdministrator, string reason)
        {
            reason = reason.Trim();
            if (reason.Length is < 3 or > 500)
                throw new InvalidOperationException("Cancellation reason must contain between 3 and 500 characters.");

            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var reservation = await LockedReservationAsync(id);
            if (reservation == null || (!isAdministrator && reservation.UserId != userId))
                return null;

            if (reservation.Status == "Cancelled")
                return _mapper.Map<ReservationResponse>(reservation);
            if (!isAdministrator && reservation.StartTime <= DateTime.UtcNow.AddHours(_options.CancellationNoticeHours))
                throw new InvalidOperationException($"Reservations must be cancelled at least {_options.CancellationNoticeHours} hours before the start time.");

            var previousStatus = reservation.Status;
            ReservationLifecycle.RequireTransition(reservation.Status, "Cancelled", reservation.EndTime, DateTime.UtcNow);
            reservation.Status = "Cancelled";
            reservation.CancelledAt = DateTime.UtcNow;
            reservation.CancellationReason = reason;
            reservation.UpdatedAt = DateTime.UtcNow;
            _dbContext.AuditLogs.Add(new AuditLog
            {
                UserId = userId,
                EntityType = nameof(Reservation),
                EntityId = reservation.Id,
                Action = "Cancelled",
                PreviousState = previousStatus,
                NewState = reservation.Status,
                Reason = reason,
                Method = "DOMAIN",
                Path = $"/Reservations/{reservation.Id}/cancel",
                StatusCode = 200,
                IpAddress = "domain",
                CorrelationId = Guid.NewGuid().ToString("N")
            });
            var settledPayment = await _dbContext.Payments
                .Where(x => x.ReservationId == reservation.Id && x.Status == "Completed")
                .Select(x => new { x.Id, x.Amount })
                .SingleOrDefaultAsync();
            var hasRefundOperation = settledPayment is not null && await _dbContext.ProviderRefundOperations
                .AnyAsync(x => x.PaymentId == settledPayment.Id && x.Status != "Failed");
            if (settledPayment is not null && settledPayment.Amount > 0 && !hasRefundOperation && !await _dbContext.AccountCredits.AnyAsync(x => x.ReservationId == reservation.Id))
                _dbContext.AccountCredits.Add(new AccountCredit { UserId = reservation.UserId, ReservationId = reservation.Id, Amount = settledPayment.Amount, Reason = "Timely reservation cancellation" });
            await _dbContext.SaveChangesAsync();
            var waiting = await _dbContext.WaitlistEntries.Where(x => x.CourtId == reservation.CourtId && x.Status == "Waiting" && x.StartTimeUtc < reservation.EndTime && x.EndTimeUtc > reservation.StartTime).OrderBy(x => x.CreatedAt).FirstOrDefaultAsync();
            if (waiting != null)
            {
                waiting.Status = "Notified"; waiting.PromotedAt = DateTime.UtcNow; await _dbContext.SaveChangesAsync();
                await _notificationService.CreateAsync(new NotificationInsertRequest { Title = "Court slot available", Message = $"A waitlisted court slot on {FormatClubTime(waiting.StartTimeUtc)} is now available.", Type = "Bookings", RecipientUserIds = new List<int> { waiting.UserId } });
            }
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Reservation cancelled",
                Message = $"Reservation #{reservation.Id} scheduled for {FormatClubTime(reservation.StartTime)} was cancelled.",
                Type = "Bookings",
                RecipientUserIds = new List<int> { reservation.UserId }
            });
            await transaction.CommitAsync();
            return _mapper.Map<ReservationResponse>(reservation);
        }

        private string FormatClubTime(DateTime utcTime)
        {
            // SQL datetime values lose their Kind, but booking timestamps are stored in UTC.
            var clubTime = TimeZoneInfo.ConvertTimeFromUtc(
                DateTime.SpecifyKind(utcTime, DateTimeKind.Utc), _timeZone);
            return $"{clubTime.ToString("dd.MM.yyyy HH:mm", CultureInfo.InvariantCulture)} (club time)";
        }

        private async Task ValidateReservationAsync(
            int courtId,
            int userId,
            DateTime startTime,
            DateTime endTime,
            int? ignoredReservationId = null)
        {
            ValidateReservationInterval(startTime, endTime);
            var courtExists = await _dbContext.Courts.AnyAsync(x => x.Id == courtId && x.IsActive);
            if (!courtExists)
                throw new InvalidOperationException("The selected court is not available.");
            var userExists = await _dbContext.Users.AnyAsync(x => x.Id == userId && x.IsActive);
            if (!userExists)
                throw new InvalidOperationException("The selected user is not active.");

            await _schedule.RequireAvailableAsync(courtId, startTime, endTime, ignoredReservationId);
        }

        private void ValidateReservationInterval(DateTime startTime, DateTime endTime)
        {
            if (startTime >= endTime)
                throw new InvalidOperationException("The reservation end time must be after its start time.");
            if (startTime < DateTime.UtcNow.AddMinutes(-1))
                throw new InvalidOperationException("Reservations cannot be created in the past.");
            if ((endTime - startTime).TotalHours > 4)
                throw new InvalidOperationException("A reservation cannot be longer than four hours.");
            if ((endTime - startTime).TotalMinutes % _options.SlotMinutes != 0)
                throw new InvalidOperationException($"Reservation duration must use {_options.SlotMinutes}-minute slots.");
            var localStart = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(startTime, DateTimeKind.Utc), _timeZone);
            var localEnd = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(endTime, DateTimeKind.Utc), _timeZone);
            if (((int)localStart.TimeOfDay.TotalMinutes - _options.OpeningHour * 60) % _options.SlotMinutes != 0 ||
                ((int)localEnd.TimeOfDay.TotalMinutes - _options.OpeningHour * 60) % _options.SlotMinutes != 0)
                throw new InvalidOperationException($"Reservations must align to {_options.SlotMinutes}-minute slots.");
            if (localStart.Date != localEnd.Date || localStart.Hour < _options.OpeningHour || localEnd.TimeOfDay > TimeSpan.FromHours(_options.ClosingHour))
                throw new InvalidOperationException("Reservation is outside club opening hours.");

        }

        public async Task<List<ReservationResponse>> CreateRecurringAsync(int userId, RecurringReservationRequest request)
        {
            if (request.Weeks < 1 || request.Weeks > _options.MaxRecurringWeeks) throw new InvalidOperationException($"Recurring bookings must contain 1 to {_options.MaxRecurringWeeks} weeks.");
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await _schedule.LockCourtsAsync(request.CourtId);
            var seriesId = Guid.NewGuid();
            var entities = new List<Reservation>();
            var court = await _dbContext.Courts.SingleOrDefaultAsync(x => x.Id == request.CourtId && x.IsActive)
                ?? throw new InvalidOperationException("The selected court is not available.");
            if (!await _dbContext.Users.AnyAsync(x => x.Id == userId && x.IsActive))
                throw new InvalidOperationException("The selected user is not active.");
            var occupations = await _schedule.GetOccupationsAsync(request.StartTime, request.EndTime.AddDays(7 * (request.Weeks - 1)));
            for (var week = 0; week < request.Weeks; week++)
            {
                var start = request.StartTime.AddDays(7 * week); var end = request.EndTime.AddDays(7 * week);
                ValidateReservationInterval(start, end);
                var busy = occupations.FirstOrDefault(x => x.Overlaps(request.CourtId, start, end));
                if (busy is not null)
                    throw new InvalidOperationException($"The court is unavailable due to an existing {busy.Kind}.");
                var entity = new Reservation { CourtId = request.CourtId, UserId = userId, StartTime = start, EndTime = end, TotalPrice = decimal.Round(court.HourlyRate * (decimal)(end - start).TotalHours, 2), Status = "Confirmed", Notes = request.Notes?.Trim(), SeriesId = seriesId };
                entities.Add(entity);
            }
            _dbContext.Reservations.AddRange(entities);
            await _dbContext.SaveChangesAsync();
            var results = entities.Select(entity => _mapper.Map<ReservationResponse>(entity)).ToList();
            await _notificationService.CreateAsync(new NotificationInsertRequest { Title = "Recurring reservations confirmed", Message = $"Your {results.Count}-week court series is confirmed.", Type = "Bookings", RecipientUserIds = new List<int> { userId } });
            await transaction.CommitAsync();
            return results;
        }

        public async Task<WaitlistEntryResponse> JoinWaitlistAsync(int userId, WaitlistRequest request)
        {
            if (request.StartTime >= request.EndTime || request.StartTime <= DateTime.UtcNow) throw new InvalidOperationException("Invalid waitlist interval.");
            var occupied = await _dbContext.Reservations.AnyAsync(x => x.CourtId == request.CourtId && x.Status != "Cancelled" && x.StartTime < request.EndTime && x.EndTime > request.StartTime);
            if (!occupied) throw new InvalidOperationException("The selected slot is currently available; reserve it directly.");
            if (await _dbContext.WaitlistEntries.AnyAsync(x => x.UserId == userId && x.CourtId == request.CourtId && x.StartTimeUtc == request.StartTime && x.EndTimeUtc == request.EndTime)) throw new InvalidOperationException("You are already on this waitlist.");
            var entry = new WaitlistEntry { UserId = userId, CourtId = request.CourtId, StartTimeUtc = request.StartTime, EndTimeUtc = request.EndTime };
            _dbContext.WaitlistEntries.Add(entry); await _dbContext.SaveChangesAsync();
            return new WaitlistEntryResponse { Id = entry.Id, CourtId = entry.CourtId, StartTimeUtc = entry.StartTimeUtc, EndTimeUtc = entry.EndTimeUtc, Status = entry.Status, CreatedAt = entry.CreatedAt };
        }

        public async Task<List<WaitlistEntryResponse>> GetWaitlistAsync(int userId, int page = 1, int pageSize = 50)
        {
            page = Math.Max(page, 1);
            pageSize = Math.Clamp(pageSize, 1, 100);
            return await _dbContext.WaitlistEntries.AsNoTracking().Where(x => x.UserId == userId)
                .OrderBy(x => x.StartTimeUtc).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new WaitlistEntryResponse { Id = x.Id, CourtId = x.CourtId, CourtName = x.Court.Name, StartTimeUtc = x.StartTimeUtc, EndTimeUtc = x.EndTimeUtc, Status = x.Status, CreatedAt = x.CreatedAt }).ToListAsync();
        }

        public async Task<List<AccountCreditResponse>> GetCreditsAsync(int userId, int page = 1, int pageSize = 50)
        {
            page = Math.Max(page, 1);
            pageSize = Math.Clamp(pageSize, 1, 100);
            return await _dbContext.AccountCredits.AsNoTracking().Where(x => x.UserId == userId)
                .OrderByDescending(x => x.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new AccountCreditResponse { Id = x.Id, ReservationId = x.ReservationId, Amount = x.Amount, Reason = x.Reason, CreatedAt = x.CreatedAt, UsedAt = x.UsedAt }).ToListAsync();
        }

        public async Task<int> AddMaintenanceBlockAsync(MaintenanceBlockRequest request)
        {
            if (request.StartTimeUtc >= request.EndTimeUtc) throw new InvalidOperationException("Maintenance end must be after its start.");
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await _schedule.LockCourtsAsync();
            var courtIds = await _dbContext.Courts.Where(x => !request.CourtId.HasValue || x.Id == request.CourtId).Select(x => x.Id).ToListAsync();
            if (courtIds.Count == 0) throw new InvalidOperationException("Court not found.");
            var occupations = await _schedule.GetOccupationsAsync(request.StartTimeUtc, request.EndTimeUtc);
            if (occupations.Any(x => courtIds.Any(id => x.Overlaps(id, request.StartTimeUtc, request.EndTimeUtc))))
                throw new InvalidOperationException("Maintenance overlaps an existing booking, tournament match or maintenance block. Resolve it first.");
            var block = new MaintenanceBlock { CourtId = request.CourtId, StartTimeUtc = request.StartTimeUtc, EndTimeUtc = request.EndTimeUtc, Reason = request.Reason.Trim() };
            _dbContext.MaintenanceBlocks.Add(block);
            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();
            return block.Id;
        }

        public async Task<bool> MarkNoShowAsync(int reservationId, int actorUserId)
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var reservation = await LockedReservationAsync(reservationId);
            if (reservation is null) return false;
            ReservationLifecycle.RequireTransition(reservation.Status, "NoShow", reservation.EndTime, DateTime.UtcNow);
            reservation.IsNoShow = true; reservation.Status = "NoShow"; reservation.UpdatedAt = DateTime.UtcNow;
            _dbContext.AuditLogs.Add(new AuditLog
            {
                UserId = actorUserId,
                EntityType = nameof(Reservation),
                EntityId = reservation.Id,
                Action = "NoShow",
                PreviousState = "Confirmed",
                NewState = reservation.Status,
                Method = "DOMAIN",
                Path = $"/Reservations/{reservation.Id}/no-show",
                StatusCode = 204,
                IpAddress = "domain",
                CorrelationId = Guid.NewGuid().ToString("N")
            });
            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();
            return true;
        }

    }
}

