"""
Teste CPU-bound: Cálculo de Números Primos
Experimento de Avaliação de Desempenho de Linguagens
"""

import time
import psutil
import os
import threading

def is_prime(n):
    """Verifica se um número é primo"""
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    for i in range(3, int(n ** 0.5) + 1, 2):
        if n % i == 0:
            return False
    return True

def calculate_primes(limit):
    """Calcula todos os números primos até o limite especificado"""
    primes = []
    for num in range(2, limit):
        if is_prime(num):
            primes.append(num)
    return primes

def get_memory_usage():
    """Retorna o uso de memória do processo atual em MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024  # Converte bytes para MB

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
            return sum(self.cpu_samples) / len(self.cpu_samples)
        return 0.0

    def _monitor(self):
        """Coleta amostras de CPU periodicamente"""
        while self.monitoring:
            cpu = self.process.cpu_percent(interval=0.1)
            if cpu > 0:  # Só adiciona se houver uso real
                self.cpu_samples.append(cpu)

def main():
    print("=" * 60)
    print("TESTE CPU-BOUND: CÁLCULO DE NÚMEROS PRIMOS")
    print("=" * 60)
    print(f"Linguagem: Python {psutil.sys.version.split()[0]}")
    print(f"Sistema Operacional: {psutil.os.name}")
    print(f"CPU: {psutil.cpu_count(logical=False)} cores físicos, {psutil.cpu_count()} threads")
    print("=" * 60)

    # Parâmetros do teste - AUMENTADO para teste mais longo
    LIMIT = 500000  # Calcula primos até 500.000 (mais demorado)

    # Memória inicial
    mem_before = get_memory_usage()

    # Inicia monitor de CPU
    cpu_monitor = CPUMonitor()
    cpu_monitor.start()

    # Medição de tempo de execução
    print(f"\nCalculando números primos até {LIMIT}...")
    print("(Aguarde, isso pode levar alguns segundos...)")
    start_time = time.time()

    primes = calculate_primes(LIMIT)

    end_time = time.time()
    execution_time = end_time - start_time

    # Para o monitoramento e obtém média de CPU
    cpu_usage = cpu_monitor.stop()

    # Memória final
    mem_after = get_memory_usage()
    mem_used = mem_after - mem_before

    # Resultados
    print("\n" + "=" * 60)
    print("RESULTADOS")
    print("=" * 60)
    print(f"Números primos encontrados: {len(primes)}")
    print(f"Tempo de execução: {execution_time:.4f} segundos")
    print(f"Memória utilizada: {mem_used:.2f} MB")
    print(f"Uso médio de CPU: {cpu_usage:.2f}%")
    print("=" * 60)

    # Salva os resultados em arquivo para análise posterior
    with open("resultado_cpu_bound.txt", "a") as f:
        f.write(f"{execution_time:.4f},{mem_used:.2f},{cpu_usage:.2f}\n")

    print("\n✓ Resultados salvos em 'resultado_cpu_bound.txt'")

if __name__ == "__main__":
    main()