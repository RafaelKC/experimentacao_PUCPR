#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste CPU-bound com C# (Instalação Automática)
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações do Experimento
REPETICOES=10
PAUSA_ENTRE_EXEC=3
PROJETO_DIR="." 

# Caminhos Ajustados:
ARQUIVO_RESULTADO="../resultados/resultado_cpu_csharp.txt"
LOG_DIR="../logs"
LOG_FILE="$LOG_DIR/log_experimento_cpu_csharp_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste CPU-bound C#${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verifica dotnet e Configura Dependências
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}❌ .NET SDK não encontrado! Instale-o antes de continuar.${NC}"
    exit 1
fi

echo -e "${YELLOW}⚙️ Instalando dependência 'System.Diagnostics.PerformanceCounter'...${NC}"
# Adiciona o pacote NuGet. O '|| true' evita que o script pare se o pacote já estiver instalado.
dotnet add package System.Diagnostics.PerformanceCounter || true

# Garante que o projeto está restaurado/pronto. Isto é crucial antes de compilar.
dotnet restore

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro na instalação ou restauração de pacotes!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependências configuradas. Compilando o código (Release)...${NC}"
# Compila e publica para garantir que o binário esteja otimizado
dotnet publish -c Release -r linux-x64 -o publish_linux /p:PublishSingleFile=true 

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro na compilação do C#!${NC}"
    exit 1
fi

BINARIO="./publish_linux/cpu_csharp"
echo -e "${GREEN}✓ Compilação OK: $BINARIO${NC}"

# 2. Prepara o Ambiente
mkdir -p "$LOG_DIR"
mkdir -p "../resultados"

if [ ! -f "$ARQUIVO_RESULTADO" ]; then
    echo "tempo_segundos,memoria_mb,cpu_percent" > "$ARQUIVO_RESULTADO"
fi

{ # Inicia o log
    echo "=========================================="
    echo "LOG DO EXPERIMENTO C# CPU"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sistema: $(uname -a)"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

echo -e "${YELLOW}⚠️  No Linux, a métrica de CPU (cpu_percent) será 0.0, pois o PerformanceCounter não funciona cross-platform. Analise o tempo e a memória.${NC}"
read -p "Pressione ENTER para iniciar o experimento..."
echo ""

# 3. Executa as repetições
echo -e "${BLUE}Iniciando experimento com $REPETICOES repetições...${NC}"
echo ""

for i in $(seq 1 $REPETICOES); do
    echo -e "${GREEN}▶ Execução $i de $REPETICOES${NC}"
    echo "----------------------------------------"

    echo "=== Execução $i - $(date '+%H:%M:%S') ===" >> "$LOG_FILE"

    # Executa o binário.
    OUTPUT_TEMP=$("$BINARIO" 2>&1)
    
    echo "$OUTPUT_TEMP" >> "$LOG_FILE"
    echo "$OUTPUT_TEMP"

    # Extrai a linha CSV.
    CSV_LINE=$(echo "$OUTPUT_TEMP" | grep "^RESULTADO_CSV:" | sed 's/RESULTADO_CSV://g')
    
    if [ -n "$CSV_LINE" ]; then
        CLEAN_CSV_LINE=$(echo "$CSV_LINE" | xargs)
        echo "$CLEAN_CSV_LINE" >> "$ARQUIVO_RESULTADO"
        echo -e "${GREEN}✓ Execução $i concluída e dado salvo em ${ARQUIVO_RESULTADO}.${NC}"
    else
        echo -e "${RED}❌ Erro: Linha CSV não encontrada na saída da execução $i.${NC}"
    fi

    echo "" >> "$LOG_FILE"

    if [ $i -lt $REPETICOES ]; then
        echo -e "${YELLOW}Aguardando ${PAUSA_ENTRE_EXEC}s para próxima execução...${NC}"
        sleep $PAUSA_ENTRE_EXEC
        echo ""
    fi
done

# Resumo final
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO CONCLUÍDO!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}📁 Resultados em: ${ARQUIVO_RESULTADO}${NC}"
echo -e "${GREEN}🗒️ Log detalhado em: ${LOG_FILE}${NC}"
echo ""
echo -e "${GREEN}✓ Script finalizado com sucesso!${NC}"