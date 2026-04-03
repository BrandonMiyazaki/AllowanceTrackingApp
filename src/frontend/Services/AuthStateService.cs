using AllowanceTracker.Models;

namespace AllowanceTracker.Services;

/// <summary>
/// Manages authentication state server-side in the Blazor circuit.
/// Token is stored in memory (per-circuit) — never sent to the browser.
/// </summary>
public class AuthStateService
{
    public string? Token { get; private set; }
    public UserInfo? CurrentUser { get; private set; }
    public bool IsLoggedIn => CurrentUser != null && !string.IsNullOrEmpty(Token);

    public void SetLogin(string token, UserInfo user)
    {
        Token = token;
        CurrentUser = user;
    }

    public void Logout()
    {
        Token = null;
        CurrentUser = null;
    }
}
