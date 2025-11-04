"""
Teste I/O-bound: Manipulação de Arquivo Grande (Leitura/Escrita)
Experimento de Avaliação de Desempenho de Linguagens
"""

import time
import psutil
import os
import threading
import hashlib


# --- Funções Auxiliares (Mesmas de cpu_bound_test.py) ---

def get_memory_usage():
    """Retorna o uso de memória do processo atual em MB"""
    process = psutil.Process(os.getpid())
    # rss (Resident Set Size) é a memória física que o processo está usando
    return process.memory_info().rss / 1024 / 1024


class CPUMonitor:
    """Monitor de uso de CPU em thread separada"""

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
            # psutil.cpu_percent retorna % por CPU, mas o Process.cpu_percent
            # é a porcentagem do uso total do sistema.
            return sum(self.cpu_samples) / len(self.cpu_samples)
        return 0.0

    def _monitor(self):
        """Coleta amostras de CPU periodicamente"""
        while self.monitoring:
            # Coleta o uso de CPU desde a última chamada
            cpu = self.process.cpu_percent(interval=0.1)
            if cpu > 0:
                self.cpu_samples.append(cpu)
            # A thread vai dormir a maior parte do tempo em I/O-bound,
            # então a coleta de CPU não será muito alta.


# -------------------------------------------------------------------

def create_dummy_file(filename, size_mb):
    """Cria um arquivo dummy com o tamanho especificado (em MB)."""
    if os.path.exists(filename) and os.path.getsize(filename) == size_mb * 1024 * 1024:
        print(f"Arquivo '{filename}' já existe com o tamanho correto ({size_mb} MB).")
        return

    print(f"Criando arquivo dummy de {size_mb} MB ({filename})...")
    chunk_size = 1024 * 1024  # 1 MB
    data = os.urandom(chunk_size)  # Dados aleatórios
    with open(filename, 'wb') as f:
        for _ in range(size_mb):
            f.write(data)
    print("Criação do arquivo concluída.")


def process_file(filename, chunk_size):
    """
    Lê o arquivo em blocos, calcula o hash de cada bloco
    (simulando processamento I/O-bound) e retorna o hash final.
    """
    total_bytes = 0
    # Usaremos SHA256 para o processamento de CPU em cada bloco I/O
    hash_object = hashlib.sha256()

    with open(filename, 'rb') as f:
        while True:
            # Esta é a operação de I/O que queremos medir
            chunk = f.read(chunk_size)
            if not chunk:
                break

            # Processamento de CPU (para evitar que o I/O seja otimizado)
            hash_object.update(chunk)
            total_bytes += len(chunk)

    return hash_object.hexdigest(), total_bytes


def main():
    # Parâmetros do experimento
    FILE_SIZE_MB = 500  # Tamanho do arquivo: 500 MB
    CHUNK_SIZE = 1024 * 1024  # Ler em blocos de 1 MB
    FILENAME = "io_test_data.bin"
    RESULT_FILE = "resultado_io_bound.txt"

    print("=" * 60)
    print("TESTE I/O-BOUND: MANIPULAÇÃO DE ARQUIVOS")
    print("=" * 60)
    print(f"Linguagem: Python {psutil.sys.version.split()[0]}")
    print(f"Sistema Operacional: {psutil.os.name}")
    print(f"Tamanho do Arquivo: {FILE_SIZE_MB} MB")
    print("=" * 60)

    # Cria o arquivo antes de iniciar a medição
    create_dummy_file(FILENAME, FILE_SIZE_MB)

    # ------------------ INÍCIO DO EXPERIMENTO ------------------

    # Memória inicial
    mem_before = get_memory_usage()

    # Inicia monitor de CPU
    cpu_monitor = CPUMonitor()
    cpu_monitor.start()

    # Medição de tempo de execução
    print(f"\nProcessando arquivo '{FILENAME}'...")
    start_time = time.time()

    final_hash, total_bytes = process_file(FILENAME, CHUNK_SIZE)

    end_time = time.time()
    execution_time = end_time - start_time

    # Para o monitoramento e obtém média de CPU
    cpu_usage = cpu_monitor.stop()

    # Memória final
    mem_after = get_memory_usage()
    mem_used = mem_after - mem_before

    # ------------------ FIM DO EXPERIMENTO ------------------

    # Resultados
    print("\n" + "=" * 60)
    print("RESULTADOS")
    print("=" * 60)
    print(f"Bytes processados: {total_bytes / (1024 * 1024):.2f} MB")
    print(f"Hash do processamento: {final_hash[:10]}...")
    print(f"Tempo de execução: {execution_time:.4f} segundos")
    print(f"Memória utilizada: {mem_used:.2f} MB")
    print(f"Uso médio de CPU: {cpu_usage:.2f}%")
    print("=" * 60)

    # Salva os resultados em arquivo para análise posterior
    with open(RESULT_FILE, "a") as f:
        f.write(f"{execution_time:.4f},{mem_used:.2f},{cpu_usage:.2f}\n")

    print(f"\n✓ Resultados salvos em '{RESULT_FILE}'")
    print("\nLembre-se de deletar o arquivo io_test_data.bin após todos os testes para liberar espaço.")


if __name__ == "__main__":
    main()