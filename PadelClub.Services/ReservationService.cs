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
using Microsoft.Extensions.Options;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public class ReservationService : BaseCRUDService<ReservationResponse, ReservationSearchObject, Reservation, ReservationInsertRequest, ReservationUpdateRequest>, IReservationService
    {
        private readonly INotificationService _notificationService;
        private readonly BookingOptions _options;
        private readonly TimeZoneInfo _timeZone;

        public ReservationService(PadelClubContext dbContext, IMapper mapper, INotificationService notificationService, IOptions<BookingOptions> options) : base(dbContext, mapper)
        {
            _notificationService = notificationService;
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

            return base.ApplyFilter(query, search);
        }

        public override async Task<ReservationResponse> CreateAsync(ReservationInsertRequest request)
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);

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
                Message = $"Your reservation for {court.Name} on {entity.StartTime:g} is confirmed.",
                Type = "Bookings",
                RecipientUserIds = new List<int> { entity.UserId }
            });
            await transaction.CommitAsync();
            return _mapper.Map<ReservationResponse>(entity);
        }

        protected override async Task BeforeUpdate(Reservation entity, ReservationUpdateRequest request)
        {
            await ValidateReservationAsync(request.CourtId, request.UserId, request.StartTime, request.EndTime, entity.Id);
            var court = await _dbContext.Courts.SingleAsync(x => x.Id == request.CourtId);
            entity.TotalPrice = decimal.Round(court.HourlyRate * (decimal)(request.EndTime - request.StartTime).TotalHours, 2);
            entity.UpdatedAt = DateTime.UtcNow;
        }

        public async Task<List<CourtAvailabilityResponse>> GetAvailabilityAsync(DateTime date)
        {
            var localDate = DateTime.SpecifyKind(date.Date, DateTimeKind.Unspecified);
            var dayStart = TimeZoneInfo.ConvertTimeToUtc(localDate.AddHours(_options.OpeningHour), _timeZone);
            var dayEnd = TimeZoneInfo.ConvertTimeToUtc(localDate.AddHours(_options.ClosingHour), _timeZone);
            var courts = await _dbContext.Courts.Where(x => x.IsActive).OrderBy(x => x.Name).ToListAsync();
            var reservations = await _dbContext.Reservations
                .Where(x => x.StartTime < dayEnd && x.EndTime > dayStart && x.Status != "Cancelled")
                .ToListAsync();
            var maintenance = await _dbContext.MaintenanceBlocks.Where(x => x.IsActive && x.StartTimeUtc < dayEnd && x.EndTimeUtc > dayStart).ToListAsync();

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
                    return new AvailabilitySlotResponse
                    {
                        StartTime = start,
                        EndTime = end,
                        Price = court.HourlyRate,
                        IsAvailable = start > DateTime.UtcNow && !reservations.Any(x =>
                            x.CourtId == court.Id && x.StartTime < end && x.EndTime > start) &&
                            !maintenance.Any(x => (!x.CourtId.HasValue || x.CourtId == court.Id) && x.StartTimeUtc < end && x.EndTimeUtc > start)
                    };
                }).ToList()
            }).ToList();
        }

        public Task<PagedResult<ReservationResponse>> GetForUserAsync(int userId, ReservationSearchObject search)
        {
            search.UserId = userId;
            return GetAsync(search);
        }

        public async Task<ReservationResponse?> CancelAsync(int id, int userId, bool isAdministrator)
        {
            var reservation = await _dbContext.Reservations.FindAsync(id);
            if (reservation == null || (!isAdministrator && reservation.UserId != userId))
                return null;

            if (reservation.Status == "Cancelled")
                return _mapper.Map<ReservationResponse>(reservation);
            if (!isAdministrator && reservation.StartTime <= DateTime.UtcNow.AddHours(_options.CancellationNoticeHours))
                throw new InvalidOperationException($"Reservations must be cancelled at least {_options.CancellationNoticeHours} hours before the start time.");

            reservation.Status = "Cancelled";
            reservation.CancelledAt = DateTime.UtcNow;
            reservation.UpdatedAt = DateTime.UtcNow;
            var settledAmount = await _dbContext.Payments.Where(x => x.ReservationId == reservation.Id && x.Status == "Completed").Select(x => (decimal?)x.Amount).SingleOrDefaultAsync();
            if (settledAmount > 0 && !await _dbContext.AccountCredits.AnyAsync(x => x.ReservationId == reservation.Id))
                _dbContext.AccountCredits.Add(new AccountCredit { UserId = reservation.UserId, ReservationId = reservation.Id, Amount = settledAmount.Value, Reason = "Timely reservation cancellation" });
            await _dbContext.SaveChangesAsync();
            var waiting = await _dbContext.WaitlistEntries.Where(x => x.CourtId == reservation.CourtId && x.Status == "Waiting" && x.StartTimeUtc < reservation.EndTime && x.EndTimeUtc > reservation.StartTime).OrderBy(x => x.CreatedAt).FirstOrDefaultAsync();
            if (waiting != null)
            {
                waiting.Status = "Notified"; waiting.PromotedAt = DateTime.UtcNow; await _dbContext.SaveChangesAsync();
                await _notificationService.CreateAsync(new NotificationInsertRequest { Title = "Court slot available", Message = $"A waitlisted court slot on {waiting.StartTimeUtc:g} is now available.", Type = "Bookings", RecipientUserIds = new List<int> { waiting.UserId } });
            }
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Reservation cancelled",
                Message = $"Reservation #{reservation.Id} scheduled for {reservation.StartTime:g} was cancelled.",
                Type = "Bookings",
                RecipientUserIds = new List<int> { reservation.UserId }
            });
            return _mapper.Map<ReservationResponse>(reservation);
        }

        private async Task ValidateReservationAsync(
            int courtId,
            int userId,
            DateTime startTime,
            DateTime endTime,
            int? ignoredReservationId = null)
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

            var courtExists = await _dbContext.Courts.AnyAsync(x => x.Id == courtId && x.IsActive);
            if (!courtExists)
                throw new InvalidOperationException("The selected court is not available.");
            var userExists = await _dbContext.Users.AnyAsync(x => x.Id == userId && x.IsActive);
            if (!userExists)
                throw new InvalidOperationException("The selected user is not active.");

            var overlaps = await _dbContext.Reservations.AnyAsync(x =>
                x.Id != ignoredReservationId &&
                x.CourtId == courtId &&
                x.Status != "Cancelled" &&
                x.StartTime < endTime &&
                x.EndTime > startTime);
            if (overlaps)
                throw new InvalidOperationException("That court has already been reserved for the selected time.");
            if (await _dbContext.MaintenanceBlocks.AnyAsync(x => x.IsActive && (!x.CourtId.HasValue || x.CourtId == courtId) && x.StartTimeUtc < endTime && x.EndTimeUtc > startTime))
                throw new InvalidOperationException("The court is unavailable due to maintenance.");
        }

        public async Task<List<ReservationResponse>> CreateRecurringAsync(int userId, RecurringReservationRequest request)
        {
            if (request.Weeks > _options.MaxRecurringWeeks) throw new InvalidOperationException($"Recurring bookings are limited to {_options.MaxRecurringWeeks} weeks.");
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var seriesId = Guid.NewGuid();
            var results = new List<ReservationResponse>();
            var court = await _dbContext.Courts.SingleAsync(x => x.Id == request.CourtId && x.IsActive);
            for (var week = 0; week < request.Weeks; week++)
            {
                var start = request.StartTime.AddDays(7 * week); var end = request.EndTime.AddDays(7 * week);
                await ValidateReservationAsync(request.CourtId, userId, start, end);
                var entity = new Reservation { CourtId = request.CourtId, UserId = userId, StartTime = start, EndTime = end, TotalPrice = decimal.Round(court.HourlyRate * (decimal)(end - start).TotalHours, 2), Status = "Confirmed", Notes = request.Notes?.Trim(), SeriesId = seriesId };
                _dbContext.Reservations.Add(entity);
                await _dbContext.SaveChangesAsync();
                results.Add(_mapper.Map<ReservationResponse>(entity));
            }
            await transaction.CommitAsync();
            await _notificationService.CreateAsync(new NotificationInsertRequest { Title = "Recurring reservations confirmed", Message = $"Your {results.Count}-week court series is confirmed.", Type = "Bookings", RecipientUserIds = new List<int> { userId } });
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

        public async Task<List<WaitlistEntryResponse>> GetWaitlistAsync(int userId) => await _dbContext.WaitlistEntries.AsNoTracking().Where(x => x.UserId == userId)
            .OrderBy(x => x.StartTimeUtc).Select(x => new WaitlistEntryResponse { Id = x.Id, CourtId = x.CourtId, StartTimeUtc = x.StartTimeUtc, EndTimeUtc = x.EndTimeUtc, Status = x.Status, CreatedAt = x.CreatedAt }).ToListAsync();

        public async Task<List<AccountCreditResponse>> GetCreditsAsync(int userId) => await _dbContext.AccountCredits.AsNoTracking().Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAt).Select(x => new AccountCreditResponse { Id = x.Id, ReservationId = x.ReservationId, Amount = x.Amount, Reason = x.Reason, CreatedAt = x.CreatedAt, UsedAt = x.UsedAt }).ToListAsync();

        public async Task<int> AddMaintenanceBlockAsync(MaintenanceBlockRequest request)
        {
            if (request.StartTimeUtc >= request.EndTimeUtc) throw new InvalidOperationException("Maintenance end must be after its start.");
            var block = new MaintenanceBlock { CourtId = request.CourtId, StartTimeUtc = request.StartTimeUtc, EndTimeUtc = request.EndTimeUtc, Reason = request.Reason.Trim() };
            _dbContext.MaintenanceBlocks.Add(block);
            await _dbContext.SaveChangesAsync();
            return block.Id;
        }

        public async Task<bool> MarkNoShowAsync(int reservationId)
        {
            var reservation = await _dbContext.Reservations.FindAsync(reservationId);
            if (reservation is null) return false;
            reservation.IsNoShow = true; reservation.Status = "NoShow"; reservation.UpdatedAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync();
            return true;
        }

    }
}

