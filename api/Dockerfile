# Compila la API con el SDK; restaura primero para reutilizar la caché de dependencias.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS compilacion
WORKDIR /src
COPY Tickets.Api.csproj ./
RUN dotnet restore Tickets.Api.csproj
COPY . ./
RUN dotnet publish Tickets.Api.csproj -c Release -o /app/publicacion --no-restore /p:UseAppHost=false

# Ejecuta solo los archivos publicados con el usuario sin privilegios de la imagen oficial.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS ejecucion
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
COPY --from=compilacion /app/publicacion ./
USER $APP_UID
ENTRYPOINT ["dotnet", "Tickets.Api.dll"]
