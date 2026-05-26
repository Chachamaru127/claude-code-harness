# AI Snapshot Workflow

An AI agent-oriented workflow leveraging the `snapshot` command of agent-browser.

---

## Overview

The `snapshot` command retrieves a page's accessibility tree and assigns reference IDs (`@e1`, `@e2`, etc.) to each element. This provides:

1. **No CSS selectors needed**: No dependency on dynamic IDs or class names
2. **Context awareness**: Each element's role (button, input, link) is explicit
3. **Deterministic interactions**: References like `@e1` allow reliable targeting

---

## Basic Workflow

### Step 1: Open the page

```bash
agent-browser open https://example.com
```

### Step 2: Get a snapshot

```bash
agent-browser snapshot -i -c
```

**Option descriptions**:
- `-i, --interactive`: Show only interactive elements (buttons, links, input fields, etc.)
- `-c, --compact`: Remove empty structural elements for a compact output

**Sample output**:
```
✓ Example Domain
  https://example.com/

- link "Home" [ref=e1]
- link "About" [ref=e2]
- button "Login" [ref=e3]
- input "Search" [ref=e4]
- button "Search" [ref=e5]
```

### Step 3: Interact via element references

```bash
# Click a link
agent-browser click @e1

# Fill the search form
agent-browser fill @e4 "search query"

# Click the search button
agent-browser click @e5
```

### Step 4: Verify results

```bash
# Get a new snapshot of the updated state
agent-browser snapshot -i -c
```

---

## Snapshot Options in Detail

### `-i, --interactive`

Show only interactive elements. Useful for narrowing down targets.

```bash
# Interactive elements only
agent-browser snapshot -i

# All elements (including text nodes)
agent-browser snapshot
```

### `-c, --compact`

Remove empty structural elements (div, span with no content, etc.).

```bash
# Compact output
agent-browser snapshot -c

# Show full structure
agent-browser snapshot
```

### `-d, --depth <n>`

Limit tree depth. Useful for getting an overview of large pages.

```bash
# Up to depth 3
agent-browser snapshot -d 3
```

### `-s, --selector <sel>`

Scope the snapshot to a specific selector.

```bash
# Only within a form
agent-browser snapshot -s "form.login"

# Only within navigation
agent-browser snapshot -s "nav"
```

### Combining options

```bash
# Recommended: interactive + compact
agent-browser snapshot -i -c

# Interactive elements only within a form
agent-browser snapshot -i -c -s "form"

# Shallow tree for an overview
agent-browser snapshot -i -d 2
```

---

## Use-Case Workflows

### Login flow

```bash
# 1. Open the login page
agent-browser open https://example.com/login

# 2. Get a snapshot
agent-browser snapshot -i -c
# Output:
# - input "Email" [ref=e1]
# - input "Password" [ref=e2]
# - button "Login" [ref=e3]
# - link "Forgot password?" [ref=e4]

# 3. Enter login credentials
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"

# 4. Click the Login button
agent-browser click @e3

# 5. Verify result
agent-browser snapshot -i -c
agent-browser get url
```

### Form submission

```bash
# 1. Open the form page
agent-browser open https://example.com/contact

# 2. Snapshot scoped to the form
agent-browser snapshot -i -c -s "form"
# Output:
# - input "Name" [ref=e1]
# - input "Email" [ref=e2]
# - textarea "Message" [ref=e3]
# - button "Send" [ref=e4]

# 3. Fill in the form
agent-browser fill @e1 "John Doe"
agent-browser fill @e2 "john@example.com"
agent-browser fill @e3 "Hello, this is a test message."

# 4. Submit
agent-browser click @e4

# 5. Verify
agent-browser snapshot -i -c
```

### Navigation exploration

```bash
# 1. Open the home page
agent-browser open https://example.com

# 2. Check navigation
agent-browser snapshot -i -c -s "nav"
# Output:
# - link "Home" [ref=e1]
# - link "Products" [ref=e2]
# - link "About" [ref=e3]
# - link "Contact" [ref=e4]

# 3. Go to Products page
agent-browser click @e2

# 4. Check the new page structure
agent-browser snapshot -i -c
```

### Dynamic content interaction

```bash
# 1. Open the page
agent-browser open https://example.com/dashboard

# 2. Initial snapshot
agent-browser snapshot -i -c

# 3. Open a dropdown
agent-browser click @e5

# 4. Wait for dynamic content to load
agent-browser wait 500

# 5. New snapshot (dropdown menu should now appear)
agent-browser snapshot -i -c
# New elements appear:
# - menuitem "Option 1" [ref=e10]
# - menuitem "Option 2" [ref=e11]
# - menuitem "Option 3" [ref=e12]

# 6. Select an option
agent-browser click @e11
```

---

## Troubleshooting

### Element not found

```bash
# Full snapshot (all elements)
agent-browser snapshot

# Narrow down with a specific selector
agent-browser snapshot -s "#target-element"

# Wait then retry
agent-browser wait 2000
agent-browser snapshot -i -c
```

### Dynamic pages

```bash
# Get snapshot after JavaScript execution
agent-browser eval "document.querySelector('#load-more').click()"
agent-browser wait 1000
agent-browser snapshot -i -c
```

### Elements inside an iframe

```bash
# Snapshot of the main frame
agent-browser snapshot -i -c

# Elements inside iframes cannot be accessed directly;
# use eval to interact with iframe content
agent-browser eval "document.querySelector('iframe').contentDocument.querySelector('button').click()"
```

---

## Best Practices

### 1. Always start with a snapshot

Always get a snapshot before interacting to understand the current state.

### 2. Use interactive + compact as defaults

```bash
agent-browser snapshot -i -c
```

### 3. Verify state after each interaction

```bash
agent-browser click @e1
agent-browser snapshot -i -c  # Verify result
```

### 4. Insert appropriate waits

When there is dynamic content, add waits:

```bash
agent-browser click @e1
agent-browser wait 500
agent-browser snapshot -i -c
```

### 5. Use sessions

Use sessions to maintain authentication state:

```bash
agent-browser --session myapp open https://example.com/login
# ... login interactions ...
# Continue using the same session
agent-browser --session myapp open https://example.com/dashboard
```
