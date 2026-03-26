# JsonPtr

Elixir implementation of JSONPointer (RFC 6901) - a toolkit for working with JSON Pointer references.

## Dependencies

- **JSON encoding**: Uses built-in `JSON` module (Elixir 1.18+) if available, otherwise falls back to `Jason` (optional dependency)

## Project Structure

```
lib/json_pointer.ex    # Main JsonPtr module (single-module library)
test/                  # ExUnit tests with doctests
mix.exs                # Project configuration
```

## Common Commands

```bash
mix test               # Run test suite
mix test --cover       # Run tests with coverage
mix format             # Format code
mix credo              # Static analysis/linting
mix dialyzer           # Type checking (first run builds PLT, takes a while)
mix docs               # Generate documentation
```

## Key Concepts

- **JsonPtr.t**: Opaque type representing a JSONPointer (internally a list of strings)
- **JsonPtr.json**: Type for JSON data (nil, boolean, string, number, list, or map)

## Main Functions

- `from_path/1`, `from_uri/1`: Parse JSON pointer strings
- `to_path/1`, `to_uri/1`: Convert pointers to strings/URIs
- `resolve_json/2`, `resolve_json!/2`: Navigate to a location in JSON data
- `update_json!/3`: Update JSON at a pointer location
- `join/2`: Append path segments to a pointer
- `backtrack/1`, `pop/1`: Navigate up the pointer hierarchy
- `map/3`, `each/3`, `reduce/4`, `flat_map/3`: Iterate over JSON collections

## Code Style

- Module uses `@opaque` for the main type to hide implementation details
- Error handling uses `{:ok, result}` / `{:error, msg}` tuples with `!` variants that raise
- Escape sequences: `~0` = `~`, `~1` = `/` (per RFC 6901)
- Doctests are heavily used - examples in docs are tested automatically
