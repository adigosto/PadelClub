using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.IService;

namespace PadelClub.WebAPI.Controllers
{
 
    public class BaseCRUDController<T, TSearch, TInsert, TUpdate> 
        : BaseController<T, TSearch> where T : class where TSearch : BaseSearchObject, new() where TInsert : class where TUpdate : class
    {
        protected readonly ICRUDService<T, TSearch, TInsert, TUpdate> _crudService;
        public BaseCRUDController(ICRUDService<T, TSearch, TInsert, TUpdate> service) : base(service)
        {
            _crudService = service;
        }

        [HttpPost]
        public virtual async Task<ActionResult<T>> Create([FromBody] TInsert request)
        {
            try
            {
                var result = await _crudService.CreateAsync(request);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(ex.Message);
            }
            catch (DbUpdateException)
            {
                return Conflict("A record with the same unique value already exists.");
            }
        }
        
        [HttpPut("{id:int}")]
        public virtual async Task<ActionResult<T?>> Update(int id, [FromBody] TUpdate request)
        {
            try
            {
                var result = await _crudService.UpdateAsync(id, request);
                if (result == null)
                {
                    return NotFound();
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(ex.Message);
            }
            catch (DbUpdateException)
            {
                return Conflict("A record with the same unique value already exists.");
            }
        }
        

        [HttpDelete("{id}")]
        public virtual async Task<ActionResult<bool>> Delete(int id)
        {
            return await _crudService.DeleteAsync(id);
        }
        

    }
}

