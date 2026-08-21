# API Error Handling Patterns

This document captures the error handling strategies across the Piggybank API layer.

## Principle

All *_api.dart files follow a consistent try/catch pattern:
- **Catch DioException**: Thrown by HTTP requests (network, timeout, parsing)
- **Convert to ApiError**: Use `ApiClient.errorFrom(e)` which extracts HTTP status and message
- **Rethrow**: Caller handles ApiError at the provider/UI level

## Pattern

```dart
Future<T> someMethod(...) async {
  try {
    final response = await _client.dio.method(...);
    return T.fromJson(response.data);
  } on DioException catch (e) {
    throw ApiClient.errorFrom(e);
  }
}
```

## HTTP Status Codes

All endpoints follow RESTful conventions:

| Status | Meaning | Retry? | Example |
|--------|---------|--------|---------|
| 200    | Success | N/A    | Account listed/created |
| 400    | Bad request | No | Invalid account name |
| 401    | Unauthorized | Refresh token, then retry | Session expired |
| 403    | Forbidden (paywall) | No | User on free plan trying premium feature |
| 404    | Not found | No | Account ID doesn't exist |
| 409    | Conflict | No | Duplicate account name in budget |
| 5xx    | Server error | Yes (with backoff) | Transient outage |

## Error Boundaries by Domain

### Accounts
- **list()**: Read-only, network errors rethrow, no retry
- **create()**: Write, validatesName/Type/Currency, may return 400/403 (paywall)
- **deactivate()**: Soft-delete, may return 404 (account gone), retry on 5xx

### Assets
- **list()**: Read-only, includes valuationDate parsing
- **create()**: Write, validates AssetType, currency handling
- **update()**: Patch-based, partial validation
- **delete()**: Hard-delete, no restore

### Budgets
- **progress()**: Query endpoint, date-based (month granularity)
- **list()**: Standard CRUD read
- **create()**: Hierarchical (parent budget allowed), may fail on circular reference
- **update()**: Flat update, no hierarchy change
- **delete()**: Cascades?—document if dependent transactions block

### Others (Liabilities, Portfolios, TFSA, Goals, Transactions)
- Follow the same list/create/update/delete pattern
- Validation errors → 400 with message
- Paywall errors → 403 with e.isPaywall flag
- Network/parsing → DioException → ApiError

## Retry Strategy (Future Enhancement)

Currently, **no automatic retries** are implemented. Candidates for future retry logic:

- **5xx errors**: Exponential backoff (1s, 2s, 4s)
- **Network timeouts**: Retry once after 1s
- **401 Unauthorized**: Trigger auth refresh, replay request

**Not retried:**
- 4xx errors (permanent, retry unlikely to help)
- 403 Forbidden (user action required)
- DELETE endpoints (idempotency assumed, but not enforced)

## Testing Strategy

### Unit Tests
- Mock ApiClient/Dio
- Inject DioException with specific statusCode
- Assert ApiError.message is extracted correctly
- Test both success and error paths

### Integration Tests
- Use local mock server (mockito or similar)
- Verify list→create→update→delete workflows
- Verify error messages propagate to UI

### Error Propagation
- API → Provider: ApiError rethrown, provider exposes via AsyncValue
- Provider → UI: _addAccountSheet catches ApiError, updates local error state
- UI → User: Error message shown in TextField error or SnackBar

## Edge Cases

1. **Network offline**: DioException with ConnectionRefused → ApiError → UI prompts retry
2. **Timeout**: DioException with ReceiveTimeout → ApiError → UI shows "slow connection"
3. **401 mid-session**: AuthController.refresh should intercept before reaching API layers
4. **Paywall on create**: isPaywall flag triggers paywall dialog, not error snackbar
5. **Stale list after mutation**: Provider invalidation triggers refresh (see accounts_provider)
