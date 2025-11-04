# =============================================================================
# Script de Execução do Experimento - Windows PowerShell
# Teste I/O-bound com C# (4GB)
# Este script deve ser executado de dentro da pasta 'io_csharp/'
# =============================================================================

# Configurações do Experimento
$REPETICOES = 10
# Aumentada a pausa, pois o teste será longo devido ao arquivo de 4GB.
$PAUSA_ENTRE_EXEC = 5 

# Caminhos Ajustados:
$ARQUIVO_RESULTADO = "..\resultados\resultado_io_csharp.txt"
$LOG_DIR = "..\logs"
$ARQUIVO_LOG = "$LOG_DIR\log_experimento_io_csharp_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$BINARIO_NAME = "io_csharp"
# Publicado para Windows (runtime win-x64)
$BINARIO = ".\publish_win\$BINARIO_NAME.exe" 

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO: Teste I/O-bound C# (4GB)" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# 1. Verifica dotnet e Restaura
try {
    dotnet --version | Out-Host
    Write-Host "✓ .NET SDK encontrado." -ForegroundColor Green
} catch {
    Write-Host "❌ .NET SDK não encontrado! Instale-o antes de continuar." -ForegroundColor Red
    exit 1
}

Write-Host "⚙️ Restaurando dependências..." -ForegroundColor Yellow
# Nenhuma dependência NuGet externa é necessária, apenas restaura o projeto.
dotnet restore

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro na restauração de pacotes!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Dependências verificadas. Compilando o código (Release)..." -ForegroundColor Green
# Compila e publica para o Windows
$compileResult = Start-Process -FilePath "dotnet" -ArgumentList "publish -c Release -r win-x64 -o publish_win /p:PublishSingleFile=true" -Wait -PassThru
if ($compileResult.ExitCode -ne 0) {
    Write-Host "❌ Erro na compilação do C#! Verifique se o código está estruturado corretamente." -ForegroundColor Red
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
LOG DO EXPERIMENTO C# I/O (4GB)
Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sistema: Windows $([System.Environment]::OSVersion.Version)
Repetições: $REPETICOES
==========================================

"@ | Out-File -FilePath $ARQUIVO_LOG -Encoding UTF8

Write-Host "⚠️  ATENÇÃO: O código C# criará um arquivo de 4GB no diretório pai. A primeira execução será LENTA, e as demais podem ser mais rápidas devido ao cache do Windows." -ForegroundColor Yellow
Read-Host "Pressione ENTER para iniciar o experimento"
Write-Host ""

# 3. Executa as repetições
Write-Host "Iniciando experimento com $REPETICOES repetições..." -ForegroundColor Blue
Write-Host ""

for ($i = 1; $i -le $REPETICOES; $i++) {
    Write-Host "▶ Execução $i de $REPETICOES" -ForegroundColor Green
    Write-Host "----------------------------------------"

    "=== Execução $i - $(Get-Date -Format 'HH:mm:ss') ===" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Executa o binário e captura a saída completa
    $output = & $BINARIO 2>&1 | Out-String
    Write-Host $output
    $output | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8
    
    # Extrai a linha CSV.
    $csvLine = $output | Select-String -Pattern "RESULTADO_CSV:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }

    if ($csvLine) {
        # Adiciona a linha CSV (limpa) ao arquivo de resultados
        $csvLine | Out-File -FilePath $ARQUIVO_RESULTADO -Append -Encoding UTF8
        Write-Host "✓ Execução $i concluída e dado salvo em $ARQUIVO_RESULTADO." -ForegroundColor Green
    } else {
        Write-Host "❌ Erro: Linha CSV não encontrada na saída da execução $i." -ForegroundColor Red
    }

    "`n" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    if ($i -lt $REPETICOES) {
        Write-Host "Aguardando ${PAUSA_ENTRE_EXEC}s para próxima execução (Sem limpeza de cache)..." -ForegroundColor Yellow
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