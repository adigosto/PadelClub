using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.IService;

namespace PadelClub.WebAPI.Controllers
{
 
    public class BaseCRUDController<T, TSearch, TInsert, TUpdate> 
        : BaseController<T, TSearch> where T : class where TSearch : class, new() where TInsert : class where TUpdate : class
    {
        protected readonly ICRUDService<T, TSearch, TInsert, TUpdate> _crudService;
        public BaseCRUDController(ICRUDService<T, TSearch, TInsert, TUpdate> service) : base(service)
        {
            _crudService = service;
        }

        [HttpPost]
        public async Task<T> Create([FromBody] TInsert request)
        {
            return await _crudService.CreateAsync(request);
        }
        
        [HttpPut("{id:int}")]
        public async Task<T?> Update(int id, [FromBody] TUpdate request)
        {
            return await _crudService.UpdateAsync(id, request);
        }
        

        [HttpDelete("{id}")]
        public async Task<bool> Delete(int id)
        {
            return await _crudService.DeleteAsync(id);
        }
        

    }
}

