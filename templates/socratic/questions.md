# Socratic Design Questions Template

段階的な質問テンプレート集。1問ずつ順番に使用する。

---

## Phase 1: Purpose（目的）

### Q1: What（何を作るか）

```markdown
🎯 **What do you want to build?**

Examples:
- "Reservation management system"
- "Blog site"
- "Task management app"
- "API server"

Rough ideas are fine!
```

### Q2: Why（なぜ必要か）

```markdown
🤔 **Why do you need it?**

What problem does it solve?
```

### Q3: Success（成功基準）

```markdown
✅ **How do you define success?**

Describe one specific scenario where you'd say "this is working!"
```

---

## Phase 2: User（ユーザー）

### Q4: Who（誰が使うか）

```markdown
👤 **Who will use this?**

a) Just yourself
b) Small team (< 5 people)
c) Larger team (5+ people)
d) Public users
```

### Q5: Where（どこで使うか）

```markdown
📱 **Where will they use it?**

a) Desktop browser
b) Desktop app
c) Mobile
d) CLI / Terminal
e) Multiple platforms
```

---

## Phase 3: Constraints（制約）

### Q6: Time（時間）

```markdown
⏰ **How much time do you have?**

a) 1 day
b) 1 week
c) 1 month
d) No deadline
```

### Q7: Tech（技術的制約）

```markdown
🔧 **Any technical constraints?**

a) Specific language/framework required → Which one?
b) Must integrate with existing system → Which system?
c) Specific hosting requirement → Where?
d) None
```

---

## Phase 4: Alternatives（代替案）

### Template: 3-way comparison

```markdown
📊 **Here are 3 approaches:**

| Option | Summary | Effort | Scalability | Recommended |
|--------|---------|--------|-------------|-------------|
| A | Simple implementation | Low | Low | |
| B | Standard implementation | Medium | Medium | ⭐ |
| C | Full implementation | High | High | |

**Recommendation: Option B**
Reason: Following YAGNI principle, sufficient for current needs.
Can migrate to Option C later if needed.

Which would you prefer? (or suggest something else)
```

---

## Phase 5: Validation（最終確認）

### Template: Summary

```markdown
📝 **Design Summary**

## Project: {name}

### Purpose
{1-2 sentences}

### Users
{who, where}

### Core Features
1. {feature 1}
2. {feature 2}
3. {feature 3}

### Tech Stack
- Language: {language}
- Framework: {framework}
- Data: {database/storage}

### Scope
- MVP: {what to build first}
- Future: {what to add later}

---

Ready to proceed to `/plan-with-agent`?

1. Yes, let's go
2. I want to change something
3. Let's discuss more
```

---

## Usage Rules

1. **1 question at a time**: Never ask multiple questions at once
2. **Wait for response**: Always wait before proceeding
3. **Use choices when possible**: a/b/c/d is easier than free text
4. **Validate incrementally**: Confirm every 200-300 words
5. **Always show alternatives**: Before any decision, show 2-3 options
