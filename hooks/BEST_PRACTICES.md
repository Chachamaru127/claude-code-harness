# Hooks Best Practices

## Shell Script Execution Permissions

**When creating or copying shell scripts to `.claude/hooks/`, always ensure execution permission is set**:

```bash
# Set execution permission for a specific script
chmod +x .claude/hooks/your-script.sh

# Set execution permission for all shell scripts in hooks
find .claude/hooks -name "*.sh" -exec chmod +x {} \;
```

### Why This Matters

Shell scripts without execution permission (`chmod +x`) will fail silently or with errors like:
```
permission denied: .claude/hooks/your-script.sh
```

### Auto-fix by Harness

`/harness-init` and `/harness-update` automatically fix permissions for `.claude/hooks/*.sh` files. However, if you manually add scripts between these commands, you must set permissions yourself.

### Checklist for Custom Hooks

When adding custom shell script hooks:

- [ ] Script has execution permission (`chmod +x`)
- [ ] Script has proper shebang (`#!/bin/bash` or `#!/usr/bin/env bash`)
- [ ] Script is tested locally before registering
- [ ] Script path in `hooks.json` is correct (relative to project root)

## Common Issues

### "permission denied" Error

**Cause**: Shell script lacks execution permission.

**Solution**:
```bash
chmod +x .claude/hooks/your-script.sh
```

### Hook Not Running (Silent Failure)

**Possible causes**:
1. Script not executable
2. Incorrect path in `hooks.json`
3. Script syntax error

**Debug steps**:
```bash
# 1. Check permission
ls -la .claude/hooks/

# 2. Test script directly
bash .claude/hooks/your-script.sh

# 3. Validate hooks.json
cat .claude/hooks.json | jq .
```

## Related

- `/harness-init` - Auto-fixes permissions on new projects
- `/harness-update` - Auto-fixes permissions during updates
