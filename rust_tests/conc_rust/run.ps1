# =============================================================================
# Script de Execução do Experimento - Windows PowerShell
# Teste Concorrente com Rust
# Este script deve ser executado de dentro da pasta 'conc_rust/'
# =============================================================================

# Configurações do Experimento
$REPETICOES = 10
$PAUSA_ENTRE_EXEC = 3

# Caminhos Ajustados:
$ARQUIVO_RESULTADO = "..\resultados\resultado_conc_rust.txt"
$LOG_DIR = "..\logs"
$ARQUIVO_LOG = "$LOG_DIR\log_experimento_conc_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$BINARIO_NAME = "conc_rust"
$BINARIO = ".\target\release\$BINARIO_NAME.exe"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO: Teste Concorrente RUST" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# 1. Verifica Cargo e Compila
try {
    cargo --version | Out-Host
    Write-Host "✓ Cargo (Rust) encontrado." -ForegroundColor Green
} catch {
    Write-Host "❌ Cargo (Rust) não encontrado! Instale o Rust antes de continuar." -ForegroundColor Red
    exit 1
}

Write-Host "Compilando o código (Release neste diretório)..." -ForegroundColor Yellow
$compileResult = Start-Process -FilePath "cargo" -ArgumentList "build --release" -Wait -PassThru
if ($compileResult.ExitCode -ne 0) {
    Write-Host "❌ Erro na compilação do Rust!" -ForegroundColor Red
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

# Inicia o log
@"
==========================================
LOG DO EXPERIMENTO RUST CONCORRENTE
Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Repetições: $REPETICOES
==========================================

"@ | Out-File -FilePath $ARQUIVO_LOG -Encoding UTF8

Write-Host "⚠️  O teste deve consumir 100% da CPU em múltiplos núcleos." -ForegroundColor Yellow
Read-Host "Pressione ENTER para iniciar o experimento"
Write-Host ""

# 3. Executa as repetições
for ($i = 1; $i -le $REPETICOES; $i++) {
    Write-Host "▶ Execução $i de $REPETICOES" -ForegroundColor Green
    Write-Host "----------------------------------------"

    "=== Execução $i - $(Get-Date -Format 'HH:mm:ss') ===" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    $output = & $BINARIO 2>&1 | Out-String
    Write-Host $output
    $output | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    $csvLine = $output | Select-String -Pattern "RESULTADO_CSV:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }

    if ($csvLine) {
        $csvLine | Out-File -FilePath $ARQUIVO_RESULTADO -Append -Encoding UTF8
        Write-Host "✓ Execução $i concluída e dado salvo em $ARQUIVO_RESULTADO." -ForegroundColor Green
    } else {
        Write-Host "❌ Erro: Linha CSV não encontrada na saída da execução $i." -ForegroundColor Red
    }

    "`n" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    if ($i -lt $REPETICOES) {
        Write-Host "Aguardando ${PAUSA_ENTRE_EXEC}s para próxima execução..." -ForegroundColor Yellow
        Start-Sleep -Seconds $PAUSA_ENTRE_EXEC
        Write-Host ""
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO CONCLUÍDO!" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "✓ Script finalizado com sucesso! (Verifique '$ARQUIVO_RESULTADO')" -ForegroundColor Green