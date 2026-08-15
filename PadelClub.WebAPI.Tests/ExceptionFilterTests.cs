using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging.Abstractions;
using PadelClub.WebAPI.Filters;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class ExceptionFilterTests
{
    [Fact]
    public void Invalid_operation_is_a_client_validation_error()
    {
        var http = new DefaultHttpContext();
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor());
        var context = new ExceptionContext(action, []) { Exception = new InvalidOperationException("Invalid coupon.") };

        new ExceptionFilter(NullLogger<ExceptionFilter>.Instance).OnException(context);

        Assert.Equal(StatusCodes.Status400BadRequest, http.Response.StatusCode);
        Assert.True(context.ExceptionHandled);
        Assert.IsType<JsonResult>(context.Result);
    }
}
