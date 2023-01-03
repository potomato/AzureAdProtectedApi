using Microsoft.AspNetCore.Mvc;

namespace tokenauth.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AnonController : ControllerBase
{
    // GET: api/<AnonController>
    [HttpGet]
    public string Get()
    {
        return "Anonymous request succeeded";
    }
}
