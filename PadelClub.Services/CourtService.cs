using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Court = PadelClub.Services.Database.Court;

namespace PadelClub.Services
{
    public class CourtService : ICourtService
    {
        private readonly PadelClubContext _dbContext;

        public CourtService(PadelClubContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<List<CourtResponse>> Get(CourtSearchObject? search)
        {
            var query = _dbContext.Courts.AsNoTracking().AsQueryable();

            if (search != null)
            {
                if (!string.IsNullOrWhiteSpace(search.Name))
                {
                    query = query.Where(c => c.Name.Contains(search.Name));
                }

                if (search.IsIndoor.HasValue)
                {
                    query = query.Where(c => c.IsIndoor == search.IsIndoor.Value);
                }

                if (search.IsActive.HasValue)
                {
                    query = query.Where(c => c.IsActive == search.IsActive.Value);
                }

                if (!string.IsNullOrWhiteSpace(search.FTS))
                {
                    query = query.Where(c => 
                        c.Name.Contains(search.FTS) ||
                        (c.Description != null && c.Description.Contains(search.FTS)));
                }
            }

            var courts = await query.ToListAsync();
            return courts.Select(c => MapToResponse(c)!).ToList();
        }

        public async Task<CourtResponse?> GetById(int id)
        {
            var court = await _dbContext.Courts.FindAsync(id);
            if (court == null)
                return null;
            return MapToResponse(court);
        }

        public async Task<CourtResponse> Create(CourtRequest request)
        {
            var court = new Court
            {
                Name = request.Name,
                Description = request.Description,
                IsIndoor = request.IsIndoor,
                IsActive = request.IsActive,
                HourlyRate = request.HourlyRate,
                MaxPlayers = request.MaxPlayers
            };

            _dbContext.Courts.Add(court);
            await _dbContext.SaveChangesAsync();
            return MapToResponse(court)!;
        }

        public async Task<CourtResponse?> Update(int id, CourtRequest request)
        {
            var existingCourt = await _dbContext.Courts.FindAsync(id);
            if (existingCourt == null)
                return null;

            existingCourt.Name = request.Name;
            existingCourt.Description = request.Description;
            existingCourt.IsIndoor = request.IsIndoor;
            existingCourt.IsActive = request.IsActive;
            existingCourt.HourlyRate = request.HourlyRate;
            existingCourt.MaxPlayers = request.MaxPlayers;
            existingCourt.UpdatedAt = DateTime.UtcNow;

            await _dbContext.SaveChangesAsync();
            return MapToResponse(existingCourt);
        }

        public async Task<bool> Delete(int id)
        {
            var court = await _dbContext.Courts.FindAsync(id);
            if (court == null)
                return false;

            _dbContext.Courts.Remove(court);
            await _dbContext.SaveChangesAsync();
            return true;
        }

        public CourtResponse? MapToResponse(Court court)
        {
            if (court == null)
                return null;

            return new CourtResponse
            {
                Id = court.Id,
                Name = court.Name,
                Description = court.Description,
                IsIndoor = court.IsIndoor,
                IsActive = court.IsActive,
                HourlyRate = court.HourlyRate,
                MaxPlayers = court.MaxPlayers,
                CreatedAt = court.CreatedAt,
                UpdatedAt = court.UpdatedAt
            };
        }
    }
}

