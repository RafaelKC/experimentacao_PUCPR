# =============================================================================
# Script de Execução do Experimento - Windows PowerShell
# Teste CPU-bound com Rust
# =============================================================================

# Configurações
$REPETICOES = 10
$PAUSA_ENTRE_EXEC = 3
# Arquivos de resultados no diretório raiz do projeto 'cpu_bound_test'
$ARQUIVO_RESULTADO = "resultado_cpu_rust.txt"
$LOG_DIR = "logs"
$ARQUIVO_LOG = "$LOG_DIR\log_experimento_rust_cpu_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
# Diretório onde o script está sendo executado (raiz do projeto)
$PROJETO_DIR = "."
$BINARIO = "$PROJETO_DIR\target\release\cpu_bound_test.exe" # Nome do binário

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO: Teste CPU-bound RUST" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# 1. Verifica e Compila o Código
try {
    cargo --version | Out-Host
    Write-Host "✓ Cargo (Rust) encontrado." -ForegroundColor Green
} catch {
    Write-Host "❌ Cargo (Rust) não encontrado! Instale o Rust antes de continuar." -ForegroundColor Red
    exit 1
}

Write-Host "Compilando o código (Release)..." -ForegroundColor Yellow
# Compila o projeto usando o Cargo.toml no diretório atual
$compileResult = Start-Process -FilePath "cargo" -ArgumentList "build --release --manifest-path $PROJETO_DIR\Cargo.toml" -Wait -PassThru
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

# 2. Prepara o Ambiente
New-Item -Path $LOG_DIR -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

if (-not (Test-Path $ARQUIVO_RESULTADO)) {
    "tempo_segundos,memoria_mb,cpu_percent" | Out-File -FilePath $ARQUIVO_RESULTADO -Encoding UTF8
}

# Inicia o log
# ... (Lógica de log inalterada) ...

Write-Host "⚠️  IMPORTANTE: Feche outros programas pesados." -ForegroundColor Yellow
Read-Host "Pressione ENTER para iniciar o experimento"
Write-Host ""

# 3. Executa as repetições
for ($i = 1; $i -le $REPETICOES; $i++) {
    Write-Host "▶ Execução $i de $REPETICOES" -ForegroundColor Green
    Write-Host "----------------------------------------"

    "=== Execução $i - $(Get-Date -Format 'HH:mm:ss') ===" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Executa o binário
    $output = & $BINARIO 2>&1 | Out-String
    Write-Host $output
    $output | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Extrai a linha CSV
    $csvLine = $output | Select-String -Pattern "RESULTADO_CSV:" | ForEach-Object { $_.ToString().Split(':')[1] }

    if ($csvLine) {
        $csvLine | Out-File -FilePath $ARQUIVO_RESULTADO -Append -Encoding UTF8
        Write-Host "✓ Execução $i concluída e dado salvo." -ForegroundColor Green
    } else {
        Write-Host "❌ Erro na execução ou na captura de dados $i" -ForegroundColor Red
    }

    "`n" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    if ($i -lt $REPETICOES) {
        Start-Sleep -Seconds $PAUSA_ENTRE_EXEC
    }
}

Write-Host ""
Write-Host "✓ Script finalizado com sucesso! (Verifique '$ARQUIVO_RESULTADO')" -ForegroundColor Green