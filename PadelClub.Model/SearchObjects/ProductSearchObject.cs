using System;
using System.Collections.Generic;
using System.Text;

namespace PadelClub.Model.SearchObjects
{
    public class ProductSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }
        public string? NameGTE { get; set; }
    }
}
