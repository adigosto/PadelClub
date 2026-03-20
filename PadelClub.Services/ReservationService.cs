using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public class ReservationService : BaseCRUDService<ReservationResponse, ReservationSearchObject, Reservation, ReservationRequest, ReservationRequest>, IReservationService
    {
        public ReservationService(PadelClubContext dbContext) : base(dbContext)
        {
        }

        protected override IQueryable<Reservation> ApplyFilter(IQueryable<Reservation> query, ReservationSearchObject search)
        {
            if (search != null)
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
            }

            return query;
        }

        protected override Reservation MapInsertToEntity(Reservation entity, ReservationRequest request)
        {
            entity.CourtId = request.CourtId;
            entity.UserId = request.UserId;
            entity.StartTime = request.StartTime;
            entity.EndTime = request.EndTime;
            entity.TotalPrice = request.TotalPrice;
            entity.Status = request.Status;
            entity.Notes = request.Notes;

            return entity;
        }

        protected override void MapUpdateToEntity(Reservation entity, ReservationRequest request)
        {
            entity.CourtId = request.CourtId;
            entity.UserId = request.UserId;
            entity.StartTime = request.StartTime;
            entity.EndTime = request.EndTime;
            entity.TotalPrice = request.TotalPrice;
            entity.Status = request.Status;
            entity.Notes = request.Notes;

        }

        // public async Task<ReservationResponse> Create(ReservationRequest request)
        // {
        //     var reservation = new Reservation
        //     {
        //         CourtId = request.CourtId,
        //         UserId = request.UserId,
        //         StartTime = request.StartTime,
        //         EndTime = request.EndTime,
        //         TotalPrice = request.TotalPrice,
        //         Status = request.Status,
        //         Notes = request.Notes
        //     };

        //     _dbContext.Reservations.Add(reservation);
        //     await _dbContext.SaveChangesAsync();
        //     return MapToResponse(reservation)!;
        // }

        // public async Task<ReservationResponse?> Update(int id, ReservationRequest request)
        // {
        //     var existingReservation = await _dbContext.Reservations.FindAsync(id);
        //     if (existingReservation == null)
        //         return null;

        //     existingReservation.CourtId = request.CourtId;
        //     existingReservation.UserId = request.UserId;
        //     existingReservation.StartTime = request.StartTime;
        //     existingReservation.EndTime = request.EndTime;
        //     existingReservation.TotalPrice = request.TotalPrice;
        //     existingReservation.Status = request.Status;
        //     existingReservation.Notes = request.Notes;
        //     existingReservation.UpdatedAt = DateTime.UtcNow;

        //     await _dbContext.SaveChangesAsync();
        //     return MapToResponse(existingReservation);
        // }

        // public async Task<bool> Delete(int id)
        // {
        //     var reservation = await _dbContext.Reservations.FindAsync(id);
        //     if (reservation == null)
        //         return false;

        //     _dbContext.Reservations.Remove(reservation);
        //     await _dbContext.SaveChangesAsync();
        //     return true;
        // }

        protected override ReservationResponse MapToResponse(Reservation reservation)
        {
            if (reservation == null)
                throw new ArgumentNullException(nameof(reservation));

            return new ReservationResponse
            {
                Id = reservation.Id,
                CourtId = reservation.CourtId,
                UserId = reservation.UserId,
                StartTime = reservation.StartTime,
                EndTime = reservation.EndTime,
                TotalPrice = reservation.TotalPrice,
                Status = reservation.Status,
                Notes = reservation.Notes,
                CreatedAt = reservation.CreatedAt,
                UpdatedAt = reservation.UpdatedAt
            };
        }
    }
}

