// Teste Concorrente: Multithreading (Parallel.For)
// Este é o código C# ajustado para a estrutura tradicional e CPU normalizada.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Experimentacao
{
    public class ConcTest
    {
        // Limite maior para garantir que a tarefa paralela demore o suficiente
        private const int LIMIT = 10_000_000; 
        // Intervalo de monitoramento (rápido para capturar picos de CPU)
        private const int MONITOR_INTERVAL_MS = 10; 

        // =================================================================
        // ESTRUTURAS E MONITORAMENTO
        // =================================================================

        public class CpuSample
        {
            public TimeSpan TotalProcessorTime { get; set; }
            public TimeSpan ElapsedTime { get; set; }
        }

        private static double GetMemoryUsageMB(Process process)
        {
            // WorkingSet64 é a memória física que o processo está usando (RSS equivalente)
            return process.WorkingSet64 / 1024.0 / 1024.0;
        }

        // Monitora o uso de CPU (usando Process.TotalProcessorTime para cross-platform)
        private static void MonitorResources(Process process, List<CpuSample> cpuSamples, ManualResetEventSlim stopSignal)
        {
            Stopwatch monitorStopwatch = Stopwatch.StartNew();
            TimeSpan lastProcessorTime = process.TotalProcessorTime;
            
            while (!stopSignal.Wait(MONITOR_INTERVAL_MS))
            {
                process.Refresh(); 
                
                TimeSpan currentProcessorTime = process.TotalProcessorTime;
                
                // Amostra de CPU: Captura a diferença de tempo de CPU usado
                CpuSample sample = new CpuSample
                {
                    TotalProcessorTime = currentProcessorTime - lastProcessorTime,
                    ElapsedTime = monitorStopwatch.Elapsed 
                };

                lock (cpuSamples)
                {
                    cpuSamples.Add(sample);
                }

                lastProcessorTime = currentProcessorTime;
            }
        }

        // =================================================================
        // TAREFA CONCORRENTE
        // =================================================================
        
        private static bool IsPrime(int n)
        {
            if (n < 2) return false;
            if (n == 2) return true;
            if (n % 2 == 0) return false;

            int limit = (int)Math.Sqrt(n);
            for (int i = 3; i <= limit; i += 2)
            {
                if (n % i == 0) return false;
            }
            return true;
        }

        private static int CalculatePrimesParallel(int limit)
        {
            int count = 0;
            
            // Parallel.For divide o trabalho entre os núcleos disponíveis
            Parallel.For(2, limit, (num) =>
            {
                if (IsPrime(num))
                {
                    // Interlocked é o método mais rápido para incrementar variáveis compartilhadas.
                    Interlocked.Increment(ref count);
                }
            });
            
            return count;
        }

        // =================================================================
        // FUNÇÃO PRINCIPAL
        // =================================================================
        
        public static void Main(string[] args)
        {
            Process currentProcess = Process.GetCurrentProcess();
            double memBefore = GetMemoryUsageMB(currentProcess);

            List<CpuSample> cpuSamples = new List<CpuSample>();
            ManualResetEventSlim stopSignal = new ManualResetEventSlim(false);

            Thread monitorThread = new Thread(() => MonitorResources(currentProcess, cpuSamples, stopSignal));
            monitorThread.Start();

            // --- Execução da Tarefa ---
            Console.WriteLine("========================================");
            Console.WriteLine("TESTE CONCORRENTE: C#");
            Console.WriteLine("Limite: " + LIMIT);
            Console.WriteLine($"Cores Lógicos: {Environment.ProcessorCount}");
            Console.WriteLine("========================================");
            Console.WriteLine("\nIniciando cálculo de primos paralelo...");

            Stopwatch stopwatch = Stopwatch.StartNew();
            
            int primesCount = CalculatePrimesParallel(LIMIT);

            stopwatch.Stop();
            double executionTime = stopwatch.Elapsed.TotalSeconds; // Tempo real de execução

            // Finaliza o monitoramento
            stopSignal.Set();
            monitorThread.Join();

            currentProcess.Refresh();
            double memAfter = GetMemoryUsageMB(currentProcess);
            double memUsed = memAfter - memBefore;

            // CRUCIAL: CÁLCULO FINAL DE CPU E NORMALIZAÇÃO
            double totalSampledCpuTime = cpuSamples.Sum(s => s.TotalProcessorTime.TotalMilliseconds);
            double totalElapsedTime = stopwatch.Elapsed.TotalMilliseconds;
            int processorCount = Environment.ProcessorCount; // Número de núcleos lógicos
            
            double cpuAverage = 0.0;
            if (totalElapsedTime > 0 && processorCount > 0)
            {
                // Fórmula Normalizada (Uso em relação a um único núcleo, max ≈ 100%):
                // (Tempo total de CPU amostrado / (Tempo Real de Execução * Núcleos)) * 100
                // Isso divide o uso total do processo pelo potencial máximo do sistema (100% * Cores)
                cpuAverage = (totalSampledCpuTime / (totalElapsedTime * processorCount)) * 100.0;
            }
            // Limita o valor a 100% (embora não seja estritamente necessário para fins de medição de carga)
            cpuAverage = Math.Min(100.0, cpuAverage); 


            // --- Resultados ---
            Console.WriteLine("\n========================================");
            Console.WriteLine("RESULTADOS");
            Console.WriteLine("========================================");
            Console.WriteLine($"Primos encontrados: {primesCount}");
            Console.WriteLine($"Tempo de execução: {executionTime:F4} segundos");
            Console.WriteLine($"Memória utilizada: {memUsed:F2} MB");
            Console.WriteLine($"Uso médio de CPU: {cpuAverage:F2}%");
            Console.WriteLine("========================================");

            // SAÍDA CSV: tempo_segundos,memoria_mb,cpu_percent
            Console.WriteLine($"RESULTADO_CSV:{executionTime:F4},{memUsed:F2},{cpuAverage:F2}");
        }
    }
}