#!/bin/bash
# =============================================================================
# Script de Execução do Experimento - Linux/Mac
# Teste IO-bound com Python
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
REPETICOES=10
PAUSA_ENTRE_EXEC=3
ARQUIVO_RESULTADO="resultado_io_bound.txt"
ARQUIVO_LOG="log_experimento_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EXPERIMENTO: Teste IO-bound Python${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verifica se o Python está instalado
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 não encontrado!${NC}"
    echo "Instale Python3 antes de continuar."
    exit 1
fi

# Verifica se psutil está instalado
echo -e "${YELLOW}Verificando dependências...${NC}"
python3 -c "import psutil" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Biblioteca psutil não encontrada. Instalando...${NC}"
    pip3 install psutil
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao instalar psutil!${NC}"
        exit 1
    fi
fi

# Verifica se o arquivo de README.md existe
if [ ! -f "io_bound_test.py" ]; then
    echo -e "${RED}❌ Arquivo 'io_bound_test.py' não encontrado!${NC}"
    echo "Certifique-se de que o arquivo está no mesmo diretório."
    exit 1
fi

echo -e "${GREEN}✓ Todas as dependências OK${NC}"
echo ""

# Coleta informações do sistema
echo -e "${BLUE}Informações do Sistema:${NC}"
echo "SO: $(uname -s) $(uname -r)"
echo "IO: $(lsio | grep 'Model name' | cut -d ':' -f 2 | xargs)"
echo "Memória Total: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Python: $(python3 --version)"
echo ""

# Pergunta se deseja limpar resultados anteriores
if [ -f "$ARQUIVO_RESULTADO" ]; then
    echo -e "${YELLOW}Arquivo de resultados anterior encontrado.${NC}"
    read -p "Deseja limpar os resultados anteriores? (s/N): " limpar
    if [[ $limpar == "s" || $limpar == "S" ]]; then
        rm "$ARQUIVO_RESULTADO"
        echo -e "${GREEN}✓ Resultados anteriores removidos${NC}"
    fi
    echo ""
fi

# Cria cabeçalho do arquivo de resultados se não existir
if [ ! -f "$ARQUIVO_RESULTADO" ]; then
    echo "tempo_segundos,memoria_mb,cpu_percent" > "$ARQUIVO_RESULTADO"
fi

# Prepara o ambiente (fecha programas, etc)
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "  • Feche outros programas pesados"
echo "  • Desconecte da internet se possível"
echo "  • Aguarde o término de todos os testes"
echo ""
read -p "Pressione ENTER para iniciar o experimento..."
echo ""

# Inicia o log
{
    echo "=========================================="
    echo "LOG DO EXPERIMENTO"
    echo "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sistema: $(uname -a)"
    echo "Repetições: $REPETICOES"
    echo "=========================================="
    echo ""
} > "$ARQUIVO_LOG"

# Executa as repetições
echo -e "${BLUE}Iniciando experimento com $REPETICOES repetições...${NC}"
echo ""

for i in $(seq 1 $REPETICOES); do
    echo -e "${GREEN}▶ Execução $i de $REPETICOES${NC}"
    echo "----------------------------------------"

    # Registra no log
    echo "=== Execução $i - $(date '+%H:%M:%S') ===" >> "$ARQUIVO_LOG"

    # Executa o README.md e captura saída
    python3 io_bound_test.py 2>&1 | tee -a "$ARQUIVO_LOG"

    # Verifica se houve erro
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "${RED}❌ Erro na execução $i${NC}" | tee -a "$ARQUIVO_LOG"
    else
        echo -e "${GREEN}✓ Execução $i concluída${NC}"
    fi

    echo "" >> "$ARQUIVO_LOG"

    # Pausa entre execuções (exceto na última)
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

# Calcula estatísticas básicas
if [ -f "$ARQUIVO_RESULTADO" ]; then
    echo -e "${GREEN}Estatísticas Básicas:${NC}"
    echo "----------------------------------------"

    # Pula a primeira linha (cabeçalho) e calcula média
    awk -F',' 'NR>1 {
        sum_tempo+=$1; sum_mem+=$2; sum_io+=$3; count++
    }
    END {
        if(count>0) {
            printf "Tempo médio: %.4f segundos\n", sum_tempo/count
            printf "Memória média: %.2f MB\n", sum_mem/count
            printf "IO médio: %.2f%%\n", sum_io/count
            printf "Total de execuções: %d\n", count
        }
    }' "$ARQUIVO_RESULTADO"

    echo ""
fi

echo -e "${GREEN}📁 Arquivos gerados:${NC}"
echo "  • $ARQUIVO_RESULTADO (dados brutos)"
echo "  • $ARQUIVO_LOG (log detalhado)"
echo ""
echo -e "${YELLOW}💡 Próximos passos:${NC}"
echo "  1. Execute este script no Windows para comparação"
echo "  2. Importe os resultados para uma planilha"
echo "  3. Calcule média, mediana e desvio padrão"
echo "  4. Gere gráficos comparativos"
echo ""
echo -e "${GREEN}✓ Script finalizado com sucesso!${NC}"