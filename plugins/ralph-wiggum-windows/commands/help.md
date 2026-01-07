---
description: "Show Ralph Wiggum plugin help"
hide-from-slash-command-tool: "true"
---

# Ralph Wiggum Plugin Help (Windows)

## Commands

### /ralph-loop
Start a Ralph loop in your current session.

**Usage:**
```
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

**Options:**
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise <text>` - Phrase that signals completion

**Examples:**
```
/ralph-loop Build a REST API --completion-promise "DONE" --max-iterations 50
/ralph-loop Fix the auth bug --max-iterations 20
/ralph-loop Refactor the cache layer
```

### /cancel-ralph
Cancel the active Ralph loop.

**Usage:**
```
/cancel-ralph
```

## How It Works

1. Run `/ralph-loop` with your task
2. Work on the task normally
3. When you try to exit, the stop hook intercepts
4. Your SAME PROMPT is fed back for the next iteration
5. Loop continues until:
   - Max iterations reached, OR
   - Completion promise detected in output

## Monitoring

View current iteration:
```powershell
Get-Content .claude\ralph-loop.local.md | Select-String '^iteration:'
```

View full state:
```powershell
Get-Content .claude\ralph-loop.local.md | Select-Object -First 10
```

## Best Practices

1. **Always set `--max-iterations`** as a safety net
2. **Use clear completion criteria** in your prompt
3. **Include `--completion-promise`** for early exit when done
4. **Break large tasks into phases** with clear checkpoints

## Philosophy

- Iteration > Perfection
- Failures are data
- Persistence wins

For more details, see the README.md in the plugin directory.
