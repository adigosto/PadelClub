using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PadelClub.Services
{
    public class DummyProductService : IProductService
    {
        public List<Product> Get(ProductSearchObject? search)
        {
            List<Product> products = new List<Product>();
            products.Add(new Product()
            {
                Id = 1,
                Name = "Racket",
                Description = "Padel Racket"
            });

            var queryable = products.AsQueryable(); 

            if(!string.IsNullOrWhiteSpace(search?.Name))
            {
                queryable = queryable.Where(x => x.Name == search.Name);
            }

            if (!string.IsNullOrWhiteSpace(search?.Name))
            {
                queryable = queryable.Where(x => x.Name.StartsWith(search.NameGTE));
            }

            if (!string.IsNullOrWhiteSpace(search?.FTS))
            {
                queryable = queryable.Where(x => x.Name.Contains(search.FTS, StringComparison.CurrentCultureIgnoreCase) || x.Description.Contains(search.FTS, StringComparison.CurrentCultureIgnoreCase));
            }

            return queryable.ToList();
        }

        public Product Get(int id)
        {
            return new Product()
            {
                Id = 2,
                Name = "Ball",
                Description = "Padel Ball"
            };
        }
    }
}
