# Uruchom PowerShell jako Administrator na PC hosta (serwerze).
# Zezwala zespolowi w sieci LAN na polaczenie z Kafka, PostgreSQL, Redis, Jupyter.

$ports = @(29092, 5432, 6379, 8999)
$ruleName = "RTA_MR inventory-streaming"

foreach ($port in $ports) {
    $existing = Get-NetFirewallRule -DisplayName "$ruleName TCP $port" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule `
            -DisplayName "$ruleName TCP $port" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $port `
            -Action Allow | Out-Null
        Write-Host "Dodano regule dla portu $port"
    } else {
        Write-Host "Regula dla portu $port juz istnieje"
    }
}

Write-Host ""
Write-Host "Firewall gotowy. Podaj zespolowi swoje IP (ipconfig -> IPv4):" 
ipconfig | Select-String -Pattern "IPv4"
