using System.Net.Http.Headers;
using System.Net.Http.Json;
using AllowanceTracker.Models;

namespace AllowanceTracker.Services;

public class AllowanceApiService
{
    private readonly HttpClient _http;

    public AllowanceApiService(HttpClient http)
    {
        _http = http;
    }

    private void SetAuth(string? token)
    {
        _http.DefaultRequestHeaders.Authorization =
            string.IsNullOrEmpty(token) ? null : new AuthenticationHeaderValue("Bearer", token);
    }

    // -----------------------------------------------------------------------
    // Auth
    // -----------------------------------------------------------------------
    public async Task<LoginResponse?> LoginAsync(LoginRequest request)
    {
        var response = await _http.PostAsJsonAsync("/api/auth/login", request);
        if (!response.IsSuccessStatusCode) return null;
        return await response.Content.ReadFromJsonAsync<LoginResponse>();
    }

    public async Task<UserInfo?> RegisterAsync(string token, RegisterRequest request)
    {
        SetAuth(token);
        var response = await _http.PostAsJsonAsync("/api/auth/register", request);
        if (!response.IsSuccessStatusCode) return null;
        return await response.Content.ReadFromJsonAsync<UserInfo>();
    }

    public async Task<List<UserInfo>> GetUsersAsync(string token)
    {
        SetAuth(token);
        var response = await _http.GetAsync("/api/auth/users");
        if (!response.IsSuccessStatusCode) return new List<UserInfo>();
        return await response.Content.ReadFromJsonAsync<List<UserInfo>>() ?? new List<UserInfo>();
    }

    // -----------------------------------------------------------------------
    // Allowance
    // -----------------------------------------------------------------------
    public async Task<AllowanceResponse?> GetAllowanceAsync(string token, int userId)
    {
        SetAuth(token);
        var response = await _http.GetAsync($"/api/allowance/{userId}");
        if (!response.IsSuccessStatusCode) return null;
        return await response.Content.ReadFromJsonAsync<AllowanceResponse>();
    }

    public async Task<TransactionResponse?> AddAllowanceAsync(string token, int userId, TransactionRequest request)
    {
        SetAuth(token);
        var response = await _http.PostAsJsonAsync($"/api/allowance/{userId}/add", request);
        if (!response.IsSuccessStatusCode) return null;
        return await response.Content.ReadFromJsonAsync<TransactionResponse>();
    }

    public async Task<TransactionResponse?> DeductAllowanceAsync(string token, int userId, TransactionRequest request)
    {
        SetAuth(token);
        var response = await _http.PostAsJsonAsync($"/api/allowance/{userId}/deduct", request);
        if (!response.IsSuccessStatusCode) return null;
        return await response.Content.ReadFromJsonAsync<TransactionResponse>();
    }
}
