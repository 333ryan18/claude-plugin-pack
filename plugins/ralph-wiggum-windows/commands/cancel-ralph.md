---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash(powershell *)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

```!
powershell -Command "if (Test-Path .claude\ralph-loop.local.md) { $content = Get-Content .claude\ralph-loop.local.md -Raw; $match = [regex]::Match($content, 'iteration:\s*(\d+)'); Write-Host 'FOUND_LOOP=true'; Write-Host ('ITERATION=' + $match.Groups[1].Value) } else { Write-Host 'FOUND_LOOP=false' }"
```

Check the output above:

1. **If FOUND_LOOP=false**:
   - Say "No active Ralph loop found."

2. **If FOUND_LOOP=true**:
   - Use Bash: `powershell -Command "Remove-Item .claude\ralph-loop.local.md -Force"`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the ITERATION value from above.
