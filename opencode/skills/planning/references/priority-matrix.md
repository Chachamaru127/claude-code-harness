# Priority Matrix

## Categories

| Priority | Description | Criteria |
|----------|-------------|----------|
| **Required** | Needed for MVP (minimum viable product) | Won't work without this |
| **Recommended** | Greatly improves user experience | Nice to have, but works without |
| **Optional** | Consider for future addition | If there's time |

## Example: Reservation Management System

| Feature | Priority | Reason |
|---------|----------|--------|
| User registration/login | Required | Need authentication for reservations |
| Reservation calendar display | Required | Core feature |
| Create/edit/cancel reservations | Required | Core feature |
| Admin dashboard | Recommended | Improves operational efficiency |
| Email notifications | Recommended | Improves user experience |
| Payment feature | Optional | Can add later |
| Review feature | Optional | Can add later |

## Plans.md Template

```markdown
## 🎯 Project: {{Project Name}}

### Overview
- **Purpose**: {{what you want to do}}
- **Target**: {{who will use it}}
- **Reference**: {{similar service}}
- **Scope**: {{MVP or full features}}

### Tech Stack
- Frontend: {{tech}}
- Backend: {{tech}}
- Database: {{tech}}
- Deploy: {{tech}}

---

## 🔴 Phase 1: Foundation Setup `cc:TODO`

- [ ] Project initialization
- [ ] Basic setup (linter, formatter)
- [ ] Database design
- [ ] Environment variable setup
- [ ] Git init & initial commit

## 🟡 Phase 2: Core Features (Required) `cc:TODO`

### {{Required Feature 1}} `[feature:tdd]`

#### Test Case Design (Agreed before implementation)
| Test Case | Input | Expected Output | Notes |
|-----------|-------|-----------------|-------|
| Normal: basic | {{example}} | {{expected}} | From user hearing |
| Boundary | {{boundary value}} | {{expected behavior}} | Confirmed |
| Error | {{error input}} | {{error}} | Tacit knowledge |

#### Implementation Tasks
- [ ] Create test file
- [ ] Create implementation code
- [ ] Refactor

### {{Auth Feature}} `[feature:security]`

## 🟢 Phase 3: Recommended Features `cc:TODO`

- [ ] {{UI feature}} `[feature:a11y]`
- [ ] {{recommended feature}}

## 🔵 Phase 4: Finishing `cc:TODO`

- [ ] Review (`/harness-review`)
- [ ] Deploy setup
- [ ] Operation check
```
