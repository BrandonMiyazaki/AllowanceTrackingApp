namespace AllowanceTracker.Models;

public class UserInfo
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class LoginResponse
{
    public string Token { get; set; } = string.Empty;
    public UserInfo User { get; set; } = new();
}

public class RegisterRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Role { get; set; } = "kid";
}

public class Transaction
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedByName { get; set; }
}

public class AllowanceResponse
{
    public UserInfo User { get; set; } = new();
    public decimal Balance { get; set; }
    public List<Transaction> Transactions { get; set; } = new();
}

public class TransactionRequest
{
    public decimal Amount { get; set; }
    public string? Description { get; set; }
}

public class TransactionResponse
{
    public Transaction Transaction { get; set; } = new();
    public decimal NewBalance { get; set; }
}

public class ApiError
{
    public string Error { get; set; } = string.Empty;
}
