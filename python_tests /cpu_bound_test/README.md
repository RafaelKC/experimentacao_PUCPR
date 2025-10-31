# Teste CPU-bound - Cálculo de Números Primos

## O que faz

Calcula todos os números primos de 2 até 500.000 e mede:
- Tempo de execução (segundos)
- Uso de memória (MB)
- Uso de CPU (%)

## Como testa

1. Algoritmo de verificação de primalidade por divisão
2. Executa 10 repetições automáticas
3. Salva resultados em CSV para análise estatística

## Requisitos

- Python 3.7+
- Biblioteca: `pip install psutil`

## Execução

**Linux/Mac:**
```bash
chmod +x executar_experimento.sh
./run.sh
```

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\run.ps1
```

## Resultados

Arquivo gerado: `resultado_cpu_bound.txt`

```csv
tempo_segundos,memoria_mb,cpu_percent
2.3456,15.32,98.50
2.3512,15.28,97.80
```

## Importante

- Feche outros programas durante os testes
- Execute no mesmo hardware para comparação
- Use os dados para calcular média e desvio padrão