using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Reservation = PadelClub.Services.Database.Reservation;
using MapsterMapper;

namespace PadelClub.Services
{
    public abstract class BaseCRUDService<T, TSearch, TEntity, TInsert, TUpdate>
        : BaseService<T, TSearch, TEntity>
        where T : class
        where TSearch : BaseSearchObject
        where TEntity : class, new()
        where TInsert : class
        where TUpdate : class
    {
        protected readonly PadelClubContext _dbContext;
        protected readonly IMapper _mapper;

        public BaseCRUDService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
            _dbContext = dbContext;
            _mapper = mapper;
        }


        public virtual async Task<T> CreateAsync(TInsert request)
        {
            var entity = new TEntity();
            entity = MapInsertToEntity(entity, request);

            await BeforeInsert(entity, request);

            _dbContext.Set<TEntity>().Add(entity);
            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity)!;
        }

        protected virtual Task BeforeInsert(TEntity entity, TInsert request)
        {
            return Task.CompletedTask;
        }

        protected virtual TEntity MapInsertToEntity(TEntity entity, TInsert request)
        {
            return _mapper.Map(request, entity);
        }

        public virtual async Task<T?> UpdateAsync(int id, TUpdate request)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return null;

            MapUpdateToEntity(entity, request);
            await BeforeUpdate(entity, request);
            _dbContext.Set<TEntity>().Update(entity);

            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity);
        }

        protected virtual Task BeforeUpdate(TEntity entity, TUpdate request)
        {
            return Task.CompletedTask;
        }
        protected virtual void MapUpdateToEntity(TEntity entity, TUpdate request)
        {
            _mapper.Map(request, entity);
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

        protected virtual Task BeforeDelete(TEntity entity)
        {
            return Task.CompletedTask;
        }

    }
}

