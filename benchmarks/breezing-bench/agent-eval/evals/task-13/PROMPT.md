Add a `parseSetCookie(header: string)` function to the HTTP header parser.
The type definitions are in `types.ts`.
This parses a Set-Cookie header string and returns the name, value, and attributes (expires, max-age, path, domain, secure, httponly, samesite).
