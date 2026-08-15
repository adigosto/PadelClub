namespace PadelClub.WebAPI.Filters
{
    using Microsoft.EntityFrameworkCore;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.AspNetCore.Mvc.Filters;
    using PadelClub.Model.Exceptions;
    using System.Net;

    public class ExceptionFilter : ExceptionFilterAttribute
    {
        private readonly ILogger<ExceptionFilter> _logger;

        public ExceptionFilter(ILogger<ExceptionFilter> logger)
        {
            _logger = logger;
        }

        public override void OnException(ExceptionContext context)
        {
            string key;
            string message;
            HttpStatusCode status;
            if (context.Exception is UserException or ArgumentException or InvalidOperationException)
            {
                key = "validationError";
                message = context.Exception.Message;
                status = HttpStatusCode.BadRequest;
            }
            else if (context.Exception is KeyNotFoundException)
            {
                key = "notFound";
                message = context.Exception.Message;
                status = HttpStatusCode.NotFound;
            }
            else if (context.Exception is DbUpdateException)
            {
                key = "conflict";
                message = "The operation conflicts with existing data.";
                status = HttpStatusCode.Conflict;
            }
            else
            {
                key = "serverError";
                message = "An unexpected server error occurred. Reference the correlation ID when contacting support.";
                status = HttpStatusCode.InternalServerError;
                _logger.LogError(context.Exception, "Unhandled API exception. CorrelationId: {CorrelationId}", context.HttpContext.TraceIdentifier);
            }

            context.ModelState.AddModelError(key, message);
            context.HttpContext.Response.StatusCode = (int)status;

            var list = context.ModelState.Where(x => x.Value?.Errors.Count > 0)
                .ToDictionary(x => x.Key, y => y.Value!.Errors.Select(z => z.ErrorMessage).ToArray());

            context.Result = new JsonResult(new
            {
                errors = list,
                correlationId = context.HttpContext.TraceIdentifier
            });
            context.ExceptionHandled = true;
        }
    }
}
