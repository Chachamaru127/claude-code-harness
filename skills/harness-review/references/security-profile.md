# Security Reviewer Profile

Security-focused review profile activated by `harness-review --security`.
Based on the OWASP Top 10, comprehensively checks authentication, authorization, secrets, and dependency vulnerabilities.

> **Read-only constraint**: Reviewers operating under this profile
> use Read / Grep / Glob / Bash (read-only commands only).
> Write / Edit / write-side Bash are never executed.

---

## Security Review Flow

### Step 1: Identify scope

```bash
# Collect changed files (BASE_REF is inherited from the caller)
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff "${BASE_REF:-HEAD~1}" -- ${CHANGED_FILES}
```

### Step 2: OWASP Top 10 Check

Check each of the following items against the **change diff** and **related files**.

#### A01: Broken Access Control

| Check item | Verification method |
|------------|---------|
| Missing authorization checks | Is authentication middleware applied to route/endpoint definitions? |
| Horizontal privilege escalation | Is filtering by `userId` etc. applied when retrieving user-owned resources? |
| Vertical privilege escalation | Are role checks (admin/user/guest etc.) properly implemented? |
| IDOR | Are IDs in URL parameters or request bodies accepted without authorization? |
| Directory traversal | Are path operations containing `../` sanitized? |

**Detection patterns (verify with Grep)**:
```bash
# Candidate routes without authentication
grep -rn "app\.\(get\|post\|put\|delete\|patch\)" --include="*.ts" --include="*.js"
# DB queries without userId
grep -rn "findById\|findOne\|select.*where" --include="*.ts"
```

#### A02: Cryptographic Failures

| Check item | Verification method |
|------------|---------|
| Storing sensitive information in plaintext | Are passwords, tokens, PII stored in plaintext in DB/logs? |
| Weak hash algorithms | Are MD5 / SHA1 being used for password hashing? |
| Insecure random numbers | Is `Math.random()` used for authentication token generation? |
| TLS strength | Is sensitive data transmitted/received over HTTP (non-HTTPS)? |
| Hardcoded keys | Are encryption keys/IVs embedded as constants? |

**Detection patterns**:
```bash
grep -rn "md5\|sha1\|Math\.random\(\)" --include="*.ts" --include="*.js"
grep -rn "createHash.*md5\|createHash.*sha1" --include="*.ts"
grep -rn "http://" --include="*.ts" --include="*.js" --include="*.env*"
```

#### A03: Injection

| Check item | Verification method |
|------------|---------|
| SQL injection | Is user input being concatenated into SQL strings? |
| NoSQL injection | Is `$where` or input values being used as operators in MongoDB etc.? |
| Command injection | Is user input being passed to `exec()` / `spawn()`? |
| LDAP injection | Is unsanitized input being used in LDAP queries? |
| Template injection | Is user input being passed directly to template engines? |

**Detection patterns**:
```bash
grep -rn "exec\|execSync\|spawn" --include="*.ts" --include="*.js"
grep -rn "\`SELECT\|\"SELECT\|'SELECT" --include="*.ts" --include="*.js"
grep -rn "\$where\|\$\[" --include="*.ts" --include="*.js"
```

#### A04: Insecure Design

| Check item | Verification method |
|------------|---------|
| Missing rate limiting | Is rate limiting implemented on authentication endpoints? |
| TOCTOU race conditions | Can state changes between check and use be exploited? |
| Business logic flaws | Can state transitions be executed in invalid order? |

#### A05: Security Misconfiguration

| Check item | Verification method |
|------------|---------|
| Default credentials | Are default passwords/usernames being used as-is? |
| Verbose error messages | Are stack traces or internal information returned to clients in production? |
| Unnecessary features enabled | Are debug endpoints or admin panels enabled in production? |
| HTTP security headers | Are HSTS, CSP, X-Frame-Options etc. configured? |
| CORS configuration | Is `Access-Control-Allow-Origin: *` set in production? |

**Detection patterns**:
```bash
grep -rn "cors.*origin.*\*\|allowedOrigins.*\*" --include="*.ts" --include="*.js"
grep -rn "debug.*true\|NODE_ENV.*development" --include="*.ts"
grep -rn "console\.log.*password\|console\.log.*token\|console\.log.*secret" --include="*.ts"
```

#### A06: Vulnerable and Outdated Components

| Check item | Verification method |
|------------|---------|
| Packages with known vulnerabilities | Are there versions in `package.json` dependencies with reported CVEs? |
| `npm audit` results | Are high / critical vulnerabilities left unaddressed? |
| Consistency with lock file | Is `package-lock.json` / `yarn.lock` up to date? |

**Verification commands**:
```bash
# Check dependencies in package.json (read-only)
cat package.json | grep -E '"dependencies"|"devDependencies"' -A 50 | head -60
# Check for lock file existence
ls -la package-lock.json yarn.lock pnpm-lock.yaml 2>/dev/null
```

#### A07: Identification and Authentication Failures

| Check item | Verification method |
|------------|---------|
| Brute force protection | Are login attempt limits and account lockout implemented? |
| Weak password policy | Are minimum length and complexity requirements set? |
| Session fixation attacks | Is the session ID regenerated after login? |
| Session expiry | Do long-lived sessions/tokens expire appropriately? |
| JWT validation | Is signing with `alg: none` or a weak key being accepted? |

**Detection patterns**:
```bash
grep -rn "jwt\.verify\|jwt\.sign" --include="*.ts" --include="*.js"
grep -rn "expiresIn.*\|expire.*" --include="*.ts"
grep -rn "algorithm.*none\|alg.*none" --include="*.ts" --include="*.js"
```

#### A08: Software and Data Integrity Failures

| Check item | Verification method |
|------------|---------|
| Code execution from untrusted sources | Are scripts dynamically loaded from external CDN / URL? |
| Deserialization | Is untrusted data passed directly to `eval()` / `Function()`? |
| CI/CD pipeline protection | Are build scripts executing external input without validation? |

**Detection patterns**:
```bash
grep -rn "eval(\|new Function(" --include="*.ts" --include="*.js"
grep -rn "require(.*\$\|import(.*\$" --include="*.ts" --include="*.js"
```

#### A09: Security Logging and Monitoring Failures

| Check item | Verification method |
|------------|---------|
| Authentication failure logging | Are login failures and permission errors being recorded? |
| Sensitive information in logs | Are passwords, tokens, PII included in logs? |
| Log injection | Is user input being written directly to logs (CRLF injection)? |

#### A10: Server-Side Request Forgery (SSRF)

| Check item | Verification method |
|------------|---------|
| Requests to user-specified URLs | Can user-input URLs access the internal network? |
| URL validation | Is an allowed domain list or IP filtering implemented? |
| Redirect following | Does the request library follow redirects to internal addresses? |

**Detection patterns**:
```bash
grep -rn "fetch(\|axios\.\|got(\|request(" --include="*.ts" --include="*.js"
```

---

## Authentication / Authorization Review Points

### Authentication flow

```
1. Input validation → are type, length, format checked?
2. Authentication processing → is there timing attack protection (constantTimeCompare etc.)?
3. Token issuance → is there sufficient entropy (crypto.randomBytes etc.)?
4. Token storage → is it httpOnly + Secure + SameSite Cookie, or LocalStorage?
5. Token validation → are signature, expiry, and revocation checks complete?
6. Logout → is server-side token invalidation implemented?
```

### Authorization flow

```
1. Is the required role explicitly stated for each endpoint?
2. Are checks made in both middleware and route handlers (defense in depth)?
3. Is it not relying solely on frontend visibility (backend is required)?
4. Is resource ownership verification missing?
```

---

## Handling Secrets

### Hardcode detection

```bash
# API key / secret-like patterns
grep -rn "api[_-]key\s*=\s*['\"][^'\"]\|secret\s*=\s*['\"][^'\"]" \
  --include="*.ts" --include="*.js" --include="*.sh"

# AWS / GCP / Azure credentials
grep -rn "AKIA\|sk-[a-zA-Z0-9]\{20\}\|AIza" --include="*.ts" --include="*.js"

# Hardcoded JWT signing key
grep -rn "jwt.*secret.*=\s*['\"][^'\"]\{8,\}" --include="*.ts" --include="*.js"

# Committed .env file
git diff "${BASE_REF:-HEAD~1}" -- .env .env.local .env.production
```

### Proper use of environment variables

| Good pattern | Bad pattern |
|------------|------------|
| `process.env.DATABASE_URL` | `"postgresql://user:pass@localhost/db"` |
| `process.env.JWT_SECRET` | `const JWT_SECRET = "my-super-secret"` |
| `process.env.API_KEY` | `const API_KEY = "sk-abc123..."` |

### Managing .env files

- Does `.env.example` have dummy values?
- Are `.env` / `.env.local` included in `.gitignore`?
- Are production secrets not committed in `.env.production`?

```bash
# Check .gitignore
grep -n "\.env" .gitignore 2>/dev/null
# Check that .env files are not in the repository
git diff "${BASE_REF:-HEAD~1}" --name-only | grep "\.env"
```

---

## Checking Dependencies for Known Vulnerabilities

### Steps for checking package.json

1. Read the modified `package.json`
2. Identify newly added or version-upgraded packages
3. Cross-reference with known CVE databases (NVD, Snyk, GitHub Advisory) is recommended

```bash
# Check changed packages
git diff "${BASE_REF:-HEAD~1}" -- package.json package-lock.json

# Check current dependency versions
cat package.json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k,v) for d2 in [d.get('dependencies',{}),d.get('devDependencies',{})] for k,v in d2.items()]" 2>/dev/null
```

### High-risk package categories

| Category | Caution notes |
|---------|--------|
| Authentication libraries | passport, jsonwebtoken, bcrypt — many version-dependent vulnerabilities |
| HTTP clients | axios, node-fetch, got — check default settings for SSRF protection |
| Template engines | handlebars, ejs, pug — historical RCE vulnerability cases |
| XML parsers | xml2js, fast-xml-parser — watch for XXE attacks |
| Serialization | serialize-javascript, node-serialize — RCE risk |
| Image processing | sharp, imagemagick — buffer overflow type vulnerabilities |

---

## Security Review Output Format

Uses the same JSON schema as the standard Code Review, but sets `reviewer_profile: "security"`.

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "reviewer_profile": "security",
  "critical_issues": [
    {
      "severity": "critical",
      "category": "Security",
      "owasp": "A03:2021 - Injection",
      "location": "src/api/users.ts:42",
      "issue": "User input is directly concatenated into SQL string",
      "suggestion": "Use prepared statements or an ORM",
      "cwe": "CWE-89"
    }
  ],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```

### Security-specific fields

| Field | Description |
|----------|------|
| `owasp` | Applicable OWASP Top 10 category (e.g. `A01:2021 - Broken Access Control`) |
| `cwe` | Applicable CWE number (e.g. `CWE-89`) |
| `cvss_estimate` | Approximate CVSS score (Critical: 9.0+, High: 7.0-8.9, Medium: 4.0-6.9) |

### Verdict criteria (Security mode)

Security mode applies stricter criteria than normal.

| Severity | Definition | verdict |
|--------|------|---------|
| **critical** | RCE, auth bypass, direct exposure of sensitive data, SQLi/CMDi | REQUEST_CHANGES on even 1 finding |
| **major** | Insufficient authorization checks, hardcoded secrets, weak encryption | REQUEST_CHANGES on even 1 finding |
| **minor** | Missing security headers, excessive error information, minor misconfiguration | APPROVE (with fix recommendation) |
| **recommendation** | Security best practice suggestions | APPROVE |
