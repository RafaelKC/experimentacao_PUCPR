# =============================================================================
# Script de Execução do Experimento - Windows PowerShell
# Teste Concorrente com C#
# =============================================================================

# Configurações
$REPETICOES = 10
$PAUSA_ENTRE_EXEC = 3

# Caminhos Ajustados:
$ARQUIVO_RESULTADO = "..\resultados\resultado_conc_csharp.txt"
$LOG_DIR = "..\logs"
$ARQUIVO_LOG = "$LOG_DIR\log_experimento_conc_csharp_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$BINARIO_NAME = "conc_csharp"
$BINARIO = ".\publish_win\$BINARIO_NAME.exe" 

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO: Teste Concorrente C#" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# 1. Verifica dotnet e Compila
try {
    dotnet --version | Out-Host
    Write-Host "✓ .NET SDK encontrado." -ForegroundColor Green
} catch {
    Write-Host "❌ .NET SDK não encontrado! Instale-o antes de continuar." -ForegroundColor Red
    exit 1
}

Write-Host "✓ .NET SDK encontrado. Compilando o código (Release)..." -ForegroundColor Green
dotnet restore
$compileResult = Start-Process -FilePath "dotnet" -ArgumentList "publish -c Release -r win-x64 -o publish_win /p:PublishSingleFile=true" -Wait -PassThru
if ($compileResult.ExitCode -ne 0) {
    Write-Host "❌ Erro na compilação do C#!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $BINARIO)) {
    Write-Host "❌ Binário '$BINARIO' não encontrado após a compilação!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Compilação OK." -ForegroundColor Green
Write-Host ""

# 2. Prepara o Ambiente (Logs e Resultados)
New-Item -Path $LOG_DIR -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "..\resultados" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

if (-not (Test-Path $ARQUIVO_RESULTADO)) {
    "tempo_segundos,memoria_mb,cpu_percent" | Out-File -FilePath $ARQUIVO_RESULTADO -Encoding UTF8
}

# Inicia o log (omissão para brevidade)
@"
==========================================
LOG DO EXPERIMENTO C# CONCORRENTE
Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Repetições: $REPETICOES
==========================================

"@ | Out-File -FilePath $ARQUIVO_LOG -Encoding UTF8

Write-Host "⚠️  O teste deve usar múltiplos núcleos para aceleração." -ForegroundColor Yellow
Read-Host "Pressione ENTER para iniciar o experimento"
Write-Host ""

# 3. Executa as repetições
for ($i = 1; $i -le $REPETICOES; $i++) {
    Write-Host "▶ Execução $i de $REPETICOES" -ForegroundColor Green
    Write-Host "----------------------------------------"

    $output = & $BINARIO 2>&1 | Out-String
    Write-Host $output
    
    $csvLine = $output | Select-String -Pattern "RESULTADO_CSV:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }

    if ($csvLine) {
        $csvLine | Out-File -FilePath $ARQUIVO_RESULTADO -Append -Encoding UTF8
        Write-Host "✓ Execução $i concluída e dado salvo em $ARQUIVO_RESULTADO." -ForegroundColor Green
    } else {
        Write-Host "❌ Erro: Linha CSV não encontrada na saída da execução $i." -ForegroundColor Red
    }

    if ($i -lt $REPETICOES) {
        Start-Sleep -Seconds $PAUSA_ENTRE_EXEC
    }
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO CONCLUÍDO!" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "✓ Script finalizado com sucesso! (Verifique '$ARQUIVO_RESULTADO')" -ForegroundColor Green