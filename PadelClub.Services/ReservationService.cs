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
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public class ReservationService : BaseCRUDService<ReservationResponse, ReservationSearchObject, Reservation, ReservationInsertRequest, ReservationUpdateRequest>, IReservationService
    {
        public ReservationService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
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

    }
}

