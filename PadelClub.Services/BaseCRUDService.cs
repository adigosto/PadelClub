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
    public abstract class BaseCRUDService<T, TSearch, TEntity, TRequest> 
        : BaseService<T, TSearch, TEntity>
        where T : class
        where TSearch : class
        where TEntity : class, new()
        where TRequest : class
    {
        private readonly PadelClubContext _dbContext;

        public BaseCRUDService(PadelClubContext dbContext) : base(dbContext)
        {
            _dbContext = dbContext;
        }


        public virtual async Task<T> CreateAsync(TRequest request)
        {
            var entity = new TEntity();
            entity = MapToEntity(entity, request);

            await BeforeInsert(entity, request);

            _dbContext.Set<TEntity>().Add(entity);
            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity)!;
        }

        protected virtual async Task BeforeInsert(TEntity entity, TRequest request)
        {

        }

        protected abstract TEntity MapToEntity(TEntity entity, TRequest request);

        public virtual async Task<T?> UpdateAsync(int id, TRequest request)
        {
            var existingReservation = await _dbContext.Reservations.FindAsync(id);
            if (existingReservation == null)
                return null;

            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return null;

            entity = MapToEntity(entity, request);
            await BeforeUpdate(entity, request);
            _dbContext.Set<TEntity>().Update(entity);

            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity);
        }

        protected virtual async Task BeforeUpdate(TEntity entity, TRequest request)
        {

        }

        public virtual async Task<bool> DeleteAsync(int id)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return false;

            await BeforeDelete(entity);

            _dbContext.Set<TEntity>().Remove(entity);
            await _dbContext.SaveChangesAsync();
            return true;
        }

        protected virtual async Task BeforeDelete(TEntity entity)
        {
            
        }

    }
}

