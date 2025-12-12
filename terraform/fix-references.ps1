# Backup first!
if (-not (Test-Path "backup")) {
    New-Item -ItemType Directory -Path "backup"
}
Copy-Item *.tf backup/ -Force

Write-Host "Fixing references..." -ForegroundColor Yellow

# Fix ecs.tf
(Get-Content ecs.tf) -replace 'var\.security_group_ids\["web"\]', 'aws_security_group.web.id' | Set-Content ecs.tf
Write-Host "✓ Fixed ecs.tf" -ForegroundColor Green

# Fix grafana.tf
(Get-Content grafana.tf) -replace 'var\.security_group_ids\["web"\]', 'aws_security_group.web.id' | Set-Content grafana.tf
Write-Host "✓ Fixed grafana.tf" -ForegroundColor Green

# Fix loki.tf
(Get-Content loki.tf) -replace 'var\.security_group_ids\["monitoring"\]', 'aws_security_group.monitoring.id' | Set-Content loki.tf
Write-Host "✓ Fixed loki.tf" -ForegroundColor Green

# Fix monitoring-server.tf
(Get-Content monitoring-server.tf) `
    -replace 'var\.private_subnet_ids\[0\]', 'aws_subnet.private[0].id' `
    -replace 'var\.security_group_ids\["monitoring"\]', 'aws_security_group.monitoring.id' |
    Set-Content monitoring-server.tf
Write-Host "✓ Fixed monitoring-server.tf" -ForegroundColor Green

# Fix prometheus.tf
(Get-Content prometheus.tf) -replace 'var\.security_group_ids\["monitoring"\]', 'aws_security_group.monitoring.id' | Set-Content prometheus.tf
Write-Host "✓ Fixed prometheus.tf" -ForegroundColor Green

# Fix rds.tf
(Get-Content rds.tf) -replace 'var\.security_group_ids\["database"\]', 'aws_security_group.database.id' | Set-Content rds.tf
Write-Host "✓ Fixed rds.tf" -ForegroundColor Green

Write-Host "`n✅ All files fixed!" -ForegroundColor Green
Write-Host "Run: terraform validate" -ForegroundColor Cyan