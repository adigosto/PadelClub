using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public abstract class BaseService<T, TSearch, TEntity> : IService<T, TSearch> where T : class where TSearch : class where TEntity : class
    {
        private readonly PadelClubContext _dbContext;

        public BaseService(PadelClubContext dbContext)
        {
            _dbContext = dbContext;
        }

        public virtual async Task<List<T>> GetAsync(TSearch search)
        {
            var query = _dbContext.Set<TEntity>().AsQueryable();
            query = ApplyFilter(query, search);
            var list = await query.ToListAsync();
            return list.Select(MapToResponse).ToList();
        }

        protected virtual IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query, TSearch search)
        {
            return query;
        }  

        protected abstract T MapToResponse(TEntity entity);

        public virtual async Task<T?> GetByIdAsync(int id)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return null;

            return MapToResponse(entity);
        }

    }
}

