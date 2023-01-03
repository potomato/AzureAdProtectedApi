using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace tokenauth.Controllers;

[Authorize(Roles = "Get.Keys")]
[ApiController]
[Route("api/[controller]")]
public class OrgController : ControllerBase
{
    // GET: api/<OrgController>
    [HttpGet]
    public IEnumerable<string> Get()
    {
        return User.Identities.Single().Claims.Select(c => $"{c.Type}={c.Value}");
    }
}
