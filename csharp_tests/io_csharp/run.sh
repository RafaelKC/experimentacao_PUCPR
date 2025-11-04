#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste I/O-bound com C# (4GB)
# =============================================================================

# Cores e Configurações
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
REPETICOES=10
PAUSA_ENTRE_EXEC=5 # Aumentada a pausa devido ao tamanho do arquivo

# Caminhos Ajustados:
ARQUIVO_RESULTADO="../resultados/resultado_io_csharp.txt"
LOG_DIR="../logs"
LOG_FILE="$LOG_DIR/log_experimento_io_csharp_$(date +%Y%m%d_%H%M%S).txt"
BINARIO_NAME="io_csharp"
BINARIO="./publish_linux/$BINARIO_NAME"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste I/O-bound C# (4GB)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verifica dotnet e Configura Dependências
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}❌ .NET SDK não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}⚙️ Restaurando dependências...${NC}"
# Nenhuma dependência NuGet externa é necessária (System.Security.Cryptography é padrão)
dotnet restore

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro na restauração de pacotes!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependências verificadas. Compilando o código (Release)...${NC}"
# Compila e publica
dotnet publish -c Release -r linux-x64 -o publish_linux /p:PublishSingleFile=true 

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro na compilação do C#!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Compilação OK: $BINARIO${NC}"

# 2. Prepara o Ambiente (Logs e Resultados)
mkdir -p "$LOG_DIR"
mkdir -p "../resultados"

if [ ! -f "$ARQUIVO_RESULTADO" ]; then
    echo "tempo_segundos,memoria_mb,cpu_percent" > "$ARQUIVO_RESULTADO"
fi

{ # Inicia o log
    echo "=========================================="
    echo "LOG DO EXPERIMENTO C# I/O (4GB)"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

echo -e "${YELLOW}🚨 ATENÇÃO: O código C# criará um arquivo de 4GB no diretório pai. A primeira execução será LENTA.${NC}"
read -p "Pressione ENTER para iniciar o experimento..."
echo ""

# 3. Executa as repetições (Loop de execução mantido, alterando apenas os nomes dos arquivos)
for i in $(seq 1 $REPETICOES); do
    echo -e "${GREEN}▶ Execução $i de $REPETICOES${NC}"
    echo "----------------------------------------"

    echo "=== Execução $i - $(date '+%H:%M:%S') ===" >> "$LOG_FILE"

    OUTPUT_TEMP=$("$BINARIO" 2>&1)
    
    echo "$OUTPUT_TEMP" >> "$LOG_FILE"
    echo "$OUTPUT_TEMP"

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
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO CONCLUÍDO!${NC}"
echo -e "${BLUE}========================================${NC}"