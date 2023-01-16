using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Identity.Web;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

var adConfig = builder.Configuration.GetSection("AzureAD");

builder.Services.AddAuthentication()
    .AddJwtBearer("TokensIssuedForThisApp", opts =>
    {
        // auth scheme for tokens issued for this service directly
        opts.Audience = adConfig["ThisAppAudience"];
        opts.Authority = $"https://login.microsoftonline.com/{adConfig["ThisAppTenantId"]}/";
        opts.TokenValidationParameters.ValidateLifetime = false;
    })
    .AddJwtBearer("TokensIssuedForB2CApp", opts =>
    {
        // auth scheme for tokens issued for users of a trusted B2C app
        opts.Audience = adConfig["B2CAppAudience"];
        opts.Authority = adConfig["B2CAppAuthority"];
        opts.TokenValidationParameters.ValidateLifetime = false;
    });


builder.Services.AddAuthorization(options =>
{
    // default policy if no policy applied by attribute - require auth by one of our schemes
    options.DefaultPolicy = new AuthorizationPolicyBuilder()
        .AddAuthenticationSchemes(new[] { "TokensIssuedForThisApp", "TokensIssuedForB2CApp" })
        .RequireAuthenticatedUser()
        .Build();

    options.AddPolicy("GetKeysAccess", policy =>
    {
        // policy for users with tokens issued for this app with a specific AD app role
        policy.AddAuthenticationSchemes(new[] { "TokensIssuedForThisApp" })
            .RequireAuthenticatedUser()
            .RequireRole("Get.Keys");
    });

    options.AddPolicy("B2CUsers", policy =>
    {
        // policy for users of the B2C app with a defined AD scope
        policy.AddAuthenticationSchemes(new[] { "TokensIssuedForB2CApp" })
            .RequireAuthenticatedUser()
            .RequireClaim(ClaimConstants.Scope, "DFP.Access");
    });
});

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(setup =>
{
    // Include 'SecurityScheme' to use JWT Authentication
    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        BearerFormat = "JWT",
        Name = "JWT Authentication",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = JwtBearerDefaults.AuthenticationScheme,
        Description = "Azure AD Bearer token here",

        Reference = new OpenApiReference
        {
            Id = JwtBearerDefaults.AuthenticationScheme,
            Type = ReferenceType.SecurityScheme
        }
    };

    setup.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);

    setup.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { jwtSecurityScheme, Array.Empty<string>() }
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
//if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
