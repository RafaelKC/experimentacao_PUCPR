#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste Concorrente com Rust
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações do Experimento
REPETICOES=10
PAUSA_ENTRE_EXEC=3

# Caminhos Ajustados:
ARQUIVO_RESULTADO="../resultados/resultado_conc_rust.txt"
LOG_DIR="../logs"
LOG_FILE="$LOG_DIR/log_experimento_conc_$(date +%Y%m%d_%H%M%S).txt"
BINARIO_NAME="conc_rust"
BINARIO="./target/release/$BINARIO_NAME"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste Concorrente RUST${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verifica Cargo e Compila (Lógica padrão)
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}❌ Cargo (Rust) não encontrado!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cargo encontrado. Compilando o código (Release)...${NC}"
cargo build --release

if [ $? -ne 0 ] || [ ! -f "$BINARIO" ]; then
    echo -e "${RED}❌ Erro na compilação ou binário não encontrado!${NC}"
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
    echo "LOG DO EXPERIMENTO RUST CONCORRENTE"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

echo -e "${YELLOW}⚠️  O teste deve consumir 100% da CPU em múltiplos núcleos.${NC}"
read -p "Pressione ENTER para iniciar o experimento..."
echo ""

# 3. Executa as repetições
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

# Resumo final (omissão para brevidade)
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO CONCLUÍDO!${NC}"
echo -e "${BLUE}========================================${NC}"