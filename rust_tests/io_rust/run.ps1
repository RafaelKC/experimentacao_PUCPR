#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste I/O-bound com Rust (Estrutura Separada)
# 🚨 Requere SUDO para limpar o cache do OS e medir o I/O real 🚨
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
ARQUIVO_RESULTADO="../resultados/resultado_io_rust.txt"
LOG_DIR="../logs"
LOG_FILE="$LOG_DIR/log_experimento_io_$(date +%Y%m%d_%H%M%S).txt"
BINARIO_NAME="io_rust"
BINARIO="./target/release/$BINARIO_NAME"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste I/O-bound RUST${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verifica Cargo e Compila
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

# 2. Prepara o Ambiente
mkdir -p "$LOG_DIR"
mkdir -p "../resultados"

# Cria cabeçalho do arquivo de resultados
if [ ! -f "$ARQUIVO_RESULTADO" ]; then
    echo "tempo_segundos,memoria_mb,cpu_percent" > "$ARQUIVO_RESULTADO"
fi

{ # Inicia o log
    echo "=========================================="
    echo "LOG DO EXPERIMENTO RUST I/O"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

echo -e "${YELLOW}⚠️  IMPORTANTE: O arquivo de dados (io_test_data.bin) será criado no diretório pai.${NC}"
echo -e "${RED}🚨 Prepare-se para digitar sua senha de SUDO $REPETICOES vezes para limpar o cache de disco!${NC}"
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

    # Pausa entre execuções (exceto na última)
    if [ $i -lt $REPETICOES ]; then
        echo -e "${YELLOW}Aguardando ${PAUSA_ENTRE_EXEC}s para próxima execução...${NC}"

        # --- Limpeza de Cache do OS ---
        echo -e "${YELLOW}🚨 Executando: sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'${NC}"
        sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

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
echo ""
echo -e "${GREEN}✓ Script finalizado com sucesso!${NC}"