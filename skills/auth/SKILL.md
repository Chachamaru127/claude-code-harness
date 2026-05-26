---
name: auth
description: "Explicit helper for authentication and payment implementation with Clerk, Supabase Auth, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
disable-model-invocation: true
---

# Auth Skills

Skills responsible for implementing authentication and payment features.

## Feature Details

| Feature | Details |
|---------|---------|
| **Authentication** | See [references/authentication.md](${CLAUDE_SKILL_DIR}/references/authentication.md) |
| **Payments** | See [references/payments.md](${CLAUDE_SKILL_DIR}/references/payments.md) |

## Execution Steps

1. **Quality gate** (Step 0)
2. Classify the user's request (authentication or payments)
3. Read the appropriate reference file from "Feature Details" above
4. Implement according to its contents

### Step 0: Quality Gate (Security Checklist)

Authentication and payment features always carry security risks. Before starting work, always display the following:

```markdown
Security Checklist

This work involves security-sensitive operations. Please verify the following:

### Authentication
- [ ] Passwords are hashed (bcrypt/argon2)
- [ ] Session management is secure (HTTPOnly Cookie)
- [ ] CSRF protection is implemented
- [ ] Rate limiting is in place (brute force protection)

### Payments
- [ ] Sensitive data (card numbers, etc.) is never stored on the server
- [ ] Stripe/payment provider SDK is used correctly
- [ ] Webhook signature verification is in place
- [ ] Amount tamper protection (amount is finalized server-side)

### General
- [ ] Error messages are not too detailed (prevent information leakage)
- [ ] Sensitive data is not written to logs
```

### Security Severity Display

```markdown
Caution level: HIGH

This feature carries the following risks:
- Credential exposure
- Unauthorized access
- Payment fraud

Expert review is recommended.
```

### For VibeCoder (non-technical users)

```markdown
How to safely build login and payment features

1. **"Hash" passwords**
   - Store passwords in a form that cannot be reversed
   - Safe even if data is ever leaked

2. **Never store card details on your server**
   - Delegate to a dedicated service like Stripe
   - Store nothing on your own server

3. **Keep error messages vague**
   - Use "Authentication failed" instead of "Wrong password"
   - Don't give hints to malicious actors
```
