FROM mcr.microsoft.com/dotnet/aspnet:6.0 as base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
COPY . /src
WORKDIR /src
RUN dotnet build "tokenauth.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "tokenauth.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "tokenauth.dll"]