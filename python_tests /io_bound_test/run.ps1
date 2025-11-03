# =============================================================================
# Script de Execução do Experimento - Windows PowerShell
# Teste IO-bound com Python
# =============================================================================

# Configurações
$REPETICOES = 10
$PAUSA_ENTRE_EXEC = 3
$ARQUIVO_RESULTADO = "resultado_io_bound.txt"
$ARQUIVO_LOG = "log_experimento_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO: Teste IO-bound Python" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Verifica se o Python está instalado
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python encontrado: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python não encontrado!" -ForegroundColor Red
    Write-Host "Instale Python antes de continuar."
    exit 1
}

# Verifica se psutil está instalado
Write-Host "Verificando dependências..." -ForegroundColor Yellow
try {
    python -c "import psutil" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw
    }
    Write-Host "✓ Biblioteca psutil OK" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Biblioteca psutil não encontrada. Instalando..." -ForegroundColor Yellow
    pip install psutil
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao instalar psutil!" -ForegroundColor Red
        exit 1
    }
}

# Verifica se o arquivo de README.md existe
if (-not (Test-Path "io_bound_test.py")) {
    Write-Host "❌ Arquivo 'io_bound_test.py' não encontrado!" -ForegroundColor Red
    Write-Host "Certifique-se de que o arquivo está no mesmo diretório."
    exit 1
}

Write-Host ""

# Coleta informações do sistema
Write-Host "Informações do Sistema:" -ForegroundColor Blue
Write-Host "SO: Windows $([System.Environment]::OSVersion.Version)"
Write-Host "IO: $((Get-WmiObject Win32_Processor).Name)"
Write-Host "Memória Total: $([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)) GB"
Write-Host "Python: $pythonVersion"
Write-Host ""

# Pergunta se deseja limpar resultados anteriores
if (Test-Path $ARQUIVO_RESULTADO) {
    Write-Host "Arquivo de resultados anterior encontrado." -ForegroundColor Yellow
    $limpar = Read-Host "Deseja limpar os resultados anteriores? (s/N)"
    if ($limpar -eq "s" -or $limpar -eq "S") {
        Remove-Item $ARQUIVO_RESULTADO
        Write-Host "✓ Resultados anteriores removidos" -ForegroundColor Green
    }
    Write-Host ""
}

# Cria cabeçalho do arquivo de resultados se não existir
if (-not (Test-Path $ARQUIVO_RESULTADO)) {
    "tempo_segundos,memoria_mb,io_percent" | Out-File -FilePath $ARQUIVO_RESULTADO -Encoding UTF8
}

# Prepara o ambiente
Write-Host "⚠️  IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  • Feche outros programas pesados"
Write-Host "  • Desconecte da internet se possível"
Write-Host "  • Aguarde o término de todos os testes"
Write-Host ""
Read-Host "Pressione ENTER para iniciar o experimento"
Write-Host ""

# Inicia o log
@"
==========================================
LOG DO EXPERIMENTO
Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sistema: Windows $([System.Environment]::OSVersion.Version)
Repetições: $REPETICOES
==========================================

"@ | Out-File -FilePath $ARQUIVO_LOG -Encoding UTF8

# Executa as repetições
Write-Host "Iniciando experimento com $REPETICOES repetições..." -ForegroundColor Blue
Write-Host ""

for ($i = 1; $i -le $REPETICOES; $i++) {
    Write-Host "▶ Execução $i de $REPETICOES" -ForegroundColor Green
    Write-Host "----------------------------------------"

    # Registra no log
    "=== Execução $i - $(Get-Date -Format 'HH:mm:ss') ===" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Executa o README.md e captura saída
    $output = python io_bound_test.py 2>&1 | Out-String
    Write-Host $output
    $output | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Verifica se houve erro
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro na execução $i" -ForegroundColor Red
        "ERRO na execução $i" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8
    } else {
        Write-Host "✓ Execução $i concluída" -ForegroundColor Green
    }

    "`n" | Out-File -FilePath $ARQUIVO_LOG -Append -Encoding UTF8

    # Pausa entre execuções (exceto na última)
    if ($i -lt $REPETICOES) {
        Write-Host "Aguardando ${PAUSA_ENTRE_EXEC}s para próxima execução..." -ForegroundColor Yellow
        Start-Sleep -Seconds $PAUSA_ENTRE_EXEC
        Write-Host ""
    }
}

# Resumo final
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  EXPERIMENTO CONCLUÍDO!" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Calcula estatísticas básicas
if (Test-Path $ARQUIVO_RESULTADO) {
    Write-Host "Estatísticas Básicas:" -ForegroundColor Green
    Write-Host "----------------------------------------"

    $dados = Import-Csv $ARQUIVO_RESULTADO
    $tempoMedio = ($dados.tempo_segundos | Measure-Object -Average).Average
    $memoriaMedio = ($dados.memoria_mb | Measure-Object -Average).Average
    $ioMedio = ($dados.io_percent | Measure-Object -Average).Average

    Write-Host "Tempo médio: $([math]::Round($tempoMedio, 4)) segundos"
    Write-Host "Memória média: $([math]::Round($memoriaMedio, 2)) MB"
    Write-Host "IO médio: $([math]::Round($ioMedio, 2))%"
    Write-Host "Total de execuções: $($dados.Count)"
    Write-Host ""
}

Write-Host "📁 Arquivos gerados:" -ForegroundColor Green
Write-Host "  • $ARQUIVO_RESULTADO (dados brutos)"
Write-Host "  • $ARQUIVO_LOG (log detalhado)"
Write-Host ""
Write-Host "💡 Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Execute este script no Linux para comparação"
Write-Host "  2. Importe os resultados para uma planilha"
Write-Host "  3. Calcule média, mediana e desvio padrão"
Write-Host "  4. Gere gráficos comparativos"
Write-Host ""
Write-Host "✓ Script finalizado com sucesso!" -ForegroundColor Green