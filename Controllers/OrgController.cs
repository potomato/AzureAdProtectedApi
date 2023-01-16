using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace tokenauth.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrgController : ControllerBase
{
    [Authorize]
    [HttpGet]
    public IEnumerable<string> Get()
    {
        return User.Identities.Single().Claims.Select(c => $"{c.Type}={c.Value}");
    }

    [Authorize("GetKeysAccess")]
    [HttpGet("getkey")]
    public string GetKey()
    {
        return "very-secret-value!!";
    }

    [Authorize("B2CUsers")]
    [HttpGet("getorg")]
    public string GetOrgs()
    {
        return "Organisation details";
    }
}
