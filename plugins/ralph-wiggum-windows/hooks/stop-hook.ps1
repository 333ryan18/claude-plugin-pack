# Ralph Wiggum Stop Hook (Windows PowerShell)
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

$ErrorActionPreference = "Stop"

# Read hook input from stdin
$hookInput = $input | Out-String

# Check if ralph-loop is active
$ralphStateFile = ".claude\ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    # No active loop - allow exit
    exit 0
}

# Read file content
$content = Get-Content $ralphStateFile -Raw

# Parse markdown frontmatter (YAML between ---)
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
if (-not $frontmatterMatch.Success) {
    Write-Error "Ralph loop: State file corrupted - no frontmatter found"
    Remove-Item $ralphStateFile -Force
    exit 0
}

$frontmatter = $frontmatterMatch.Groups[1].Value

# Extract values from frontmatter
$iterationMatch = [regex]::Match($frontmatter, 'iteration:\s*(\d+)')
$maxIterationsMatch = [regex]::Match($frontmatter, 'max_iterations:\s*(\d+)')
$completionPromiseMatch = [regex]::Match($frontmatter, 'completion_promise:\s*"?([^"\r\n]+)"?')

if (-not $iterationMatch.Success) {
    Write-Host "Warning: Ralph loop: State file corrupted" -ForegroundColor Yellow
    Write-Host "   File: $ralphStateFile" -ForegroundColor Yellow
    Write-Host "   Problem: 'iteration' field is not a valid number" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "   This usually means the state file was manually edited or corrupted." -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping. Run /ralph-loop again to start fresh." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

$iteration = [int]$iterationMatch.Groups[1].Value
$maxIterations = if ($maxIterationsMatch.Success) { [int]$maxIterationsMatch.Groups[1].Value } else { 0 }
$completionPromise = if ($completionPromiseMatch.Success) { $completionPromiseMatch.Groups[1].Value.Trim('"') } else { "null" }

# Check if max iterations reached
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "Ralph loop: Max iterations ($maxIterations) reached."
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Get transcript path from hook input
try {
    $hookData = $hookInput | ConvertFrom-Json
    $transcriptPath = $hookData.transcript_path
} catch {
    Write-Host "Warning: Ralph loop: Failed to parse hook input" -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

if (-not (Test-Path $transcriptPath)) {
    Write-Host "Warning: Ralph loop: Transcript file not found" -ForegroundColor Yellow
    Write-Host "   Expected: $transcriptPath" -ForegroundColor Yellow
    Write-Host "   This is unusual and may indicate a Claude Code internal issue." -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Read last assistant message from transcript (JSONL format - one JSON per line)
$transcriptContent = Get-Content $transcriptPath -Raw
$lines = $transcriptContent -split "`n" | Where-Object { $_ -match '"role":"assistant"' }

if ($lines.Count -eq 0) {
    Write-Host "Warning: Ralph loop: No assistant messages found in transcript" -ForegroundColor Yellow
    Write-Host "   Transcript: $transcriptPath" -ForegroundColor Yellow
    Write-Host "   This is unusual and may indicate a transcript format issue" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

$lastLine = $lines[-1]

try {
    $lastMessage = $lastLine | ConvertFrom-Json
    $textContent = $lastMessage.message.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }
    $lastOutput = $textContent -join "`n"
} catch {
    Write-Host "Warning: Ralph loop: Failed to parse assistant message JSON" -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Yellow
    Write-Host "   This may indicate a transcript format issue" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

if ([string]::IsNullOrEmpty($lastOutput)) {
    Write-Host "Warning: Ralph loop: Assistant message contained no text content" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Check for completion promise (only if set)
if ($completionPromise -ne "null" -and -not [string]::IsNullOrEmpty($completionPromise)) {
    # Extract text from <promise> tags
    $promiseTagMatch = [regex]::Match($lastOutput, '(?s)<promise>(.*?)</promise>')
    if ($promiseTagMatch.Success) {
        $promiseText = $promiseTagMatch.Groups[1].Value.Trim()
        # Normalize whitespace for comparison
        $promiseText = $promiseText -replace '\s+', ' '
        $expectedPromise = $completionPromise -replace '\s+', ' '

        if ($promiseText -eq $expectedPromise) {
            Write-Host "Ralph loop: Detected <promise>$completionPromise</promise>"
            Remove-Item $ralphStateFile -Force
            exit 0
        }
    }
}

# Not complete - continue loop with SAME PROMPT
$nextIteration = $iteration + 1

# Extract prompt (everything after the closing ---)
$promptMatch = [regex]::Match($content, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
if (-not $promptMatch.Success -or [string]::IsNullOrWhiteSpace($promptMatch.Groups[1].Value)) {
    Write-Host "Warning: Ralph loop: State file corrupted or incomplete" -ForegroundColor Yellow
    Write-Host "   File: $ralphStateFile" -ForegroundColor Yellow
    Write-Host "   Problem: No prompt text found" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "   This usually means:" -ForegroundColor Yellow
    Write-Host "     - State file was manually edited" -ForegroundColor Yellow
    Write-Host "     - File was corrupted during writing" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping. Run /ralph-loop again to start fresh." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

$promptText = $promptMatch.Groups[1].Value.Trim()

# Update iteration in frontmatter
$updatedContent = $content -replace 'iteration:\s*\d+', "iteration: $nextIteration"
Set-Content -Path $ralphStateFile -Value $updatedContent -NoNewline

# Build system message with iteration count and completion promise info
if ($completionPromise -ne "null" -and -not [string]::IsNullOrEmpty($completionPromise)) {
    $systemMsg = "Ralph iteration $nextIteration | To stop: output <promise>$completionPromise</promise> (ONLY when statement is TRUE - do not lie to exit!)"
} else {
    $systemMsg = "Ralph iteration $nextIteration | No completion promise set - loop runs infinitely"
}

# Output JSON to block the stop and feed prompt back
$output = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
} | ConvertTo-Json -Compress

Write-Output $output

# Exit 0 for successful hook execution
exit 0
