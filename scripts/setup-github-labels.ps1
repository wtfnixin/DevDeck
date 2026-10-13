<#
.SYNOPSIS
    Automatically creates beginner-friendly labels in the GitHub repository using gh CLI.
.DESCRIPTION
    Requires gh CLI to be authenticated (`gh auth login`).
    Repo: wtfnixin/DevDeck
#>

$repo = "wtfnixin/DevDeck"

Write-Host "🏷️ Creating DevDeck GitHub Labels for $repo..." -ForegroundColor Cyan

$labels = @(
    @{ name = "good first issue"; color = "7057ff"; description = "Good for newcomers with minimal prior context" },
    @{ name = "help wanted"; color = "008672"; description = "Extra attention is needed from the community" },
    @{ name = "first-timers-only"; color = "fbca04"; description = "Reserved specifically for first-time open-source contributors" },
    @{ name = "area: flutter"; color = "02569B"; description = "Mobile client, Flutter UI, and Dart logic" },
    @{ name = "area: desktop-agent"; color = "5319e7"; description = "Desktop backend, Node.js, sockets, and native drivers" },
    @{ name = "area: ui/ux"; color = "ff69b4"; description = "Keycaps, layout aesthetics, responsive deck grid" },
    @{ name = "area: docs"; color = "0075ca"; description = "Improvements or additions to documentation" },
    @{ name = "performance"; color = "ff7600"; description = "Latency, memory, or CPU optimizations" },
    @{ name = "enhancement"; color = "a2eeef"; description = "New feature or macro capability request" },
    @{ name = "bug"; color = "d73a4a"; description = "Something isn't working as expected" },
    @{ name = "hacktoberfest"; color = "ff7518"; description = "Issues curated for open-source month" }
)

foreach ($l in $labels) {
    Write-Host "Creating label: $($l.name)..."
    gh label create $l.name --repo $repo --color $l.color --description $l.description --force
}

Write-Host "✅ All labels created successfully!" -ForegroundColor Green
