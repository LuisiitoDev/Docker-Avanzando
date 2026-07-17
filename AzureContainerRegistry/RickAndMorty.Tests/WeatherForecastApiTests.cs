using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace RickAndMorty.Tests;

public sealed class WeatherForecastApiTests
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public WeatherForecastApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory
            .WithWebHostBuilder(builder => builder.UseEnvironment("Testing"))
            .CreateClient();
    }

    [Fact]
    public async Task GetWeatherForecast_ReturnsSuccess()
    {
        var response = await _client.GetAsync("/weatherforecast");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetWeatherForecast_ReturnsFiveItems()
    {
        var forecasts = await _client.GetFromJsonAsync<WeatherForecastResponse[]>(
            "/weatherforecast");

        Assert.NotNull(forecasts);
        Assert.Equal(5, forecasts.Length);
    }

    [Fact]
    public async Task UnknownRoute_ReturnsNotFound()
    {
        var response = await _client.GetAsync("/not-found");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private sealed record WeatherForecastResponse(
        DateOnly Date,
        int TemperatureC,
        int TemperatureF,
        string? Summary);
}
