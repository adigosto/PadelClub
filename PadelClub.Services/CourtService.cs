using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Court = PadelClub.Services.Database.Court;

namespace PadelClub.Services
{
    public class CourtService : BaseCRUDService<CourtResponse, CourtSearchObject, Court, CourtInsertRequest, CourtUpdateRequest>, ICourtService
    {

        public CourtService(PadelClubContext dbContext) : base(dbContext)
        {
            
        }

        protected override Court MapInsertToEntity(Court entity, CourtInsertRequest request)
        {
            entity.Name = request.Name;
            entity.Description = request.Description;
            entity.IsIndoor = request.IsIndoor;
            entity.IsActive = request.IsActive;
            entity.HourlyRate = request.HourlyRate;
            entity.MaxPlayers = request.MaxPlayers;
            return entity;
        }

        protected override void MapUpdateToEntity(Court entity, CourtUpdateRequest request)
        {
            entity.Name = request.Name;
            entity.Description = request.Description;
            entity.IsIndoor = request.IsIndoor;
            entity.IsActive = request.IsActive;
            entity.HourlyRate = request.HourlyRate;
            entity.MaxPlayers = request.MaxPlayers;
        }

        protected override CourtResponse MapToResponse(Court entity)
        {
            return new CourtResponse
            {
                Name = entity.Name,
                Description = entity.Description,
                IsIndoor = entity.IsIndoor,
                IsActive = entity.IsActive,
                HourlyRate = entity.HourlyRate,
                MaxPlayers = entity.MaxPlayers
            };
        }
    }
}

