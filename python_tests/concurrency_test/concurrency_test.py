"""
Teste Concorrente (Ajustado): Processamento Paralelo (via Processos)
Experimento de Avaliação de Desempenho de Linguagens
"""

import time
import psutil
import os
import threading
import multiprocessing

# --- Funções Auxiliares (Reutilizadas de testes anteriores) ---

def get_memory_usage():
    """Retorna o uso de memória do processo atual em MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024

class CPUMonitor:
    """Monitor de uso de CPU em thread separada"""
    # ... (A implementação desta classe será omitida para brevidade,
    # mas deve ser a mesma dos scripts anteriores para coletar a média de CPU)
    def __init__(self):
        self.cpu_samples = []
        self.monitoring = False
        self.process = psutil.Process(os.getpid())

    def start(self):
        """Inicia o monitoramento"""
        self.monitoring = True
        self.thread = threading.Thread(target=self._monitor)
        self.thread.daemon = True
        self.thread.start()

    def stop(self):
        """Para o monitoramento e retorna a média"""
        self.monitoring = False
        self.thread.join()
        if self.cpu_samples:
            return sum(self.cpu_samples) / len(self.cpu_samples)
        return 0.0

    def _monitor(self):
        """Coleta amostras de CPU periodicamente"""
        while self.monitoring:
            cpu = self.process.cpu_percent(interval=0.1)
            if cpu > 0:
                self.cpu_samples.append(cpu)

# -------------------------------------------------------------------

def cpu_work(n):
    """Fatora um número (tarefa CPU-bound)"""
    # Esta função é executada por cada processo worker
    i = 2
    factors = []
    d = n
    while i * i <= d:
        if d % i:
            i += 1
        else:
            factors.append(i)
            d //= i
    if d > 1:
        factors.append(d)
    return factors

def main():
    # Parâmetros do experimento
    NUM_WORKERS = psutil.cpu_count(logical=True) # Usamos o número de núcleos lógicos
    NUM_TASKS = 200 # Número de números para fatorar
    # Uma lista de números grandes para garantir que a tarefa de CPU demore
    NUMBERS_TO_FACTOR = [999999999999 + i for i in range(NUM_TASKS)]
    RESULT_FILE = "resultado_concorrencia.txt"

    print("=" * 60)
    print("TESTE CONCORRENTE: PROCESSAMENTO PARALELO (PROCESSOS)")
    print("=" * 60)
    print(f"Linguagem: Python {psutil.sys.version.split()[0]}")
    print(f"Sistema Operacional: {psutil.os.name}")
    print(f"Workers (Processos): {NUM_WORKERS}")
    print("=" * 60)

    # ------------------ INÍCIO DO EXPERIMENTO (Processos) ------------------

    mem_before = get_memory_usage()
    cpu_monitor = CPUMonitor()
    cpu_monitor.start()

    print(f"\nIniciando processamento paralelo com {NUM_WORKERS} processos...")
    start_time = time.time()

    # Utiliza um Pool de Processos para paralelizar a tarefa
    pool = multiprocessing.Pool(processes=NUM_WORKERS)
    pool.map(cpu_work, NUMBERS_TO_FACTOR)
    pool.close()
    pool.join()

    execution_time = time.time() - start_time

    cpu_usage = cpu_monitor.stop()
    mem_after = get_memory_usage()
    mem_used = mem_after - mem_before

    # ------------------ FIM DO EXPERIMENTO ------------------

    # Resultados
    print("\n" + "=" * 60)
    print("RESULTADOS")
    print("=" * 60)
    print(f"Tempo de execução: {execution_time:.4f} segundos")
    print(f"Memória utilizada (aprox.): {mem_used:.2f} MB")
    print(f"Uso médio de CPU (parent): {cpu_usage:.2f}%")
    print("=" * 60)

    # Salva os resultados no formato simplificado
    with open(RESULT_FILE, "a") as f:
        f.write(f"{execution_time:.4f},{mem_used:.2f},{cpu_usage:.2f}\n")

    print(f"\n✓ Resultados salvos em '{RESULT_FILE}'")

if __name__ == "__main__":
    main()