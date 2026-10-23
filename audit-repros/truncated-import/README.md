Truncated plan import calls nil result from loadstring

1. Load `repro.zip`. The Import dialog contains the truncated legacy plan text `do local`.
2. Click Import.

From a new game: Open the plan Import dialog, paste `do local`, and click Import.

Expected: Invalid or truncated input should be rejected without a Lua exception.

Cause: A syntax error makes `loadstring` return nil plus an error string without throwing. Therefore `pcall(loadstring, data_string)` reports success, and `Converter.read` calls the nil result.

Recovery: Replace the input with a complete valid plan export.
