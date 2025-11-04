#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste CPU-bound com Rust (Captura CSV Revisada)
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
REPETICOES=10
PAUSA_ENTRE_EXEC=3

# Caminhos Ajustados
ARQUIVO_RESULTADO="../resultados/resultado_cpu_rust.txt"
LOG_DIR="../logs"
LOG_FILE="$LOG_DIR/log_experimento_cpu_$(date +%Y%m%d_%H%M%S).txt"
BINARIO_NAME="cpu_rust"
BINARIO="./target/release/$BINARIO_NAME" # Usamos ./ para garantir que o path seja lido corretamente a partir do diretório atual

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste CPU-bound RUST (Revisão)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verifica Cargo e Compila (Lógica inalterada)
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}❌ Cargo (Rust) não encontrado!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cargo encontrado. Compilando o código (Release neste diretório)...${NC}"
cargo build --release

if [ $? -ne 0 ] || [ ! -f "$BINARIO" ]; then
    echo -e "${RED}❌ Erro na compilação ou binário não encontrado!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Compilação OK: $BINARIO${NC}"

# 2. Prepara o Ambiente
mkdir -p "$LOG_DIR"
mkdir -p "../resultados"

if [ ! -f "$ARQUIVO_RESULTADO" ]; then
    echo "tempo_segundos,memoria_mb,cpu_percent" > "$ARQUIVO_RESULTADO"
fi

{ # Inicia o log
    echo "=========================================="
    echo "LOG DO EXPERIMENTO RUST CPU"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

echo -e "${YELLOW}⚠️  IMPORTANTE: Feche outros programas pesados.${NC}"
read -p "Pressione ENTER para iniciar o experimento..."
echo ""

# 3. Executa as repetições
echo -e "${BLUE}Iniciando experimento com $REPETICOES repetições...${NC}"
echo ""

for i in $(seq 1 $REPETICOES); do
    echo -e "${GREEN}▶ Execução $i de $REPETICOES${NC}"
    echo "----------------------------------------"

    # Registra no log
    echo "=== Execução $i - $(date '+%H:%M:%S') ===" >> "$LOG_FILE"

    # Executa o binário. Capturamos TODA a saída (stdout+stderr) em uma variável temporária.
    OUTPUT_TEMP=$("$BINARIO" 2>&1)

    # 3a. Registra a saída completa no log (para debug)
    echo "$OUTPUT_TEMP" >> "$LOG_FILE"

    # 3b. Exibe a saída completa na tela (para o usuário)
    echo "$OUTPUT_TEMP"

    # 3c. Extrai a linha CSV do output. Usamos 'grep' e 'sed' para isolar e limpar.
    # O '^' garante que só pegamos a linha que começa com "RESULTADO_CSV:".
    CSV_LINE=$(echo "$OUTPUT_TEMP" | grep "^RESULTADO_CSV:" | sed 's/RESULTADO_CSV://g')

    if [ -n "$CSV_LINE" ]; then
        # Remove espaços em branco do início/fim da linha capturada, apenas por segurança
        CLEAN_CSV_LINE=$(echo "$CSV_LINE" | xargs)

        # Adiciona a linha CSV ao arquivo de resultados
        echo "$CLEAN_CSV_LINE" >> "$ARQUIVO_RESULTADO"
        echo -e "${GREEN}✓ Execução $i concluída e dado salvo em ${ARQUIVO_RESULTADO}.${NC}"
    else
        echo -e "${RED}❌ Erro: Linha CSV não encontrada na saída da execução $i. Verifique o log: $LOG_FILE${NC}"
    fi

    echo "" >> "$LOG_FILE"

    # Pausa entre execuções
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