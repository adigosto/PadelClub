using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PadelClub.Services
{
    public interface IProductService
    {
        public List<Product> Get(ProductSearchObject? search);
        public Product Get(int id);
    }
}
