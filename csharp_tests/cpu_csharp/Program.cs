// Teste CPU-bound: Cálculo de Números Primos
// Este é o código C# ajustado para a estrutura tradicional (sem Top-Level Statements)

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;

// Adicionado o namespace para corrigir os erros CS8803, CS0106 e CS0107
namespace Experimentacao
{
    public class CpuBoundTest
    {
        // O mesmo limite usado no Rust (ajustado para ser CPU-bound)
        private const int LIMIT = 5_000_000; 

        // Intervalo de monitoramento em ms
        private const int MONITOR_INTERVAL_MS = 10; // Reduzido para melhor amostragem

        // Estrutura para Amostras de CPU
        public class CpuSample
        {
            public TimeSpan TotalProcessorTime { get; set; }
            public TimeSpan ElapsedTime { get; set; }
        }

        // =================================================================
        // TAREFA CPU-BOUND (Mantida inalterada)
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

        private static List<int> CalculatePrimes(int limit)
        {
            List<int> primes = new List<int>();
            for (int num = 2; num < limit; num++)
            {
                if (IsPrime(num))
                {
                    primes.Add(num);
                }
            }
            return primes;
        }

        // =================================================================
        // MONITORAMENTO (Usando TotalProcessorTime)
        // =================================================================
        
        // Coleta o uso de memória do processo atual em MB
        private static double GetMemoryUsageMB(Process process)
        {
            return process.WorkingSet64 / 1024.0 / 1024.0;
        }

        // Monitora o uso de CPU e Memória (agora usando Process.TotalProcessorTime)
        private static void MonitorResources(Process process, List<CpuSample> cpuSamples, ManualResetEventSlim stopSignal)
        {
            // CRUCIAL: Capturamos a hora de início e o tempo de CPU no momento
            Stopwatch stopwatch = Stopwatch.StartNew();
            TimeSpan lastProcessorTime = process.TotalProcessorTime;
            
            while (!stopSignal.Wait(MONITOR_INTERVAL_MS))
            {
                // NOTA: É necessário um refresh no Process em loop para obter dados precisos
                process.Refresh(); 
                
                TimeSpan currentProcessorTime = process.TotalProcessorTime;
                
                CpuSample sample = new CpuSample
                {
                    TotalProcessorTime = currentProcessorTime - lastProcessorTime,
                    ElapsedTime = stopwatch.Elapsed 
                };

                lock (cpuSamples)
                {
                    cpuSamples.Add(sample);
                }

                lastProcessorTime = currentProcessorTime;
            }
        }

        // Ponto de entrada do programa
        public static void Main(string[] args)
        {
            Process currentProcess = Process.GetCurrentProcess();
            double memBefore = GetMemoryUsageMB(currentProcess);

            // Variáveis para monitoramento
            List<CpuSample> cpuSamples = new List<CpuSample>();
            ManualResetEventSlim stopSignal = new ManualResetEventSlim(false);

            // Inicia o monitoramento em thread separada
            Thread monitorThread = new Thread(() => MonitorResources(currentProcess, cpuSamples, stopSignal));
            monitorThread.Start();

            // --- Execução da Tarefa ---
            Console.WriteLine("========================================");
            Console.WriteLine("TESTE CPU-BOUND: C#");
            Console.WriteLine("Limite: " + LIMIT);
            Console.WriteLine("========================================");
            Console.WriteLine("\nIniciando cálculo de primos...");

            Stopwatch stopwatch = Stopwatch.StartNew();
            
            List<int> primes = CalculatePrimes(LIMIT);

            stopwatch.Stop();
            double executionTime = stopwatch.Elapsed.TotalSeconds;

            // Para o monitoramento e aguarda a thread
            stopSignal.Set();
            monitorThread.Join();

            // Coleta final de memória
            currentProcess.Refresh();
            double memAfter = GetMemoryUsageMB(currentProcess);
            double memUsed = memAfter - memBefore;

            // Calcula a média de CPU (Tempo total de CPU usado / Tempo total de amostragem * 100 * Cores)
            // Calculamos apenas o uso de CPU da thread de execução (não da thread de monitoramento)
            double totalCpuTime = currentProcess.TotalProcessorTime.TotalMilliseconds;
            double totalElapsedTime = stopwatch.Elapsed.TotalMilliseconds;
            
            // O uso de CPU em single-thread deve ser (TotalCpuTime / TotalElapsedTime) * 100
            // Se TotalCpuTime > TotalElapsedTime, é porque o SO registrou o tempo de CPU de forma diferente.
            // Aqui, usamos o cálculo de uso de CPU de *amostras* para maior precisão:
            
            double totalSampledCpuTime = cpuSamples.Sum(s => s.TotalProcessorTime.TotalMilliseconds);
            double totalSampledElapsed = cpuSamples.Sum(s => s.ElapsedTime.TotalMilliseconds); 

            // Se o monitoramento rodou por mais de 1 segundo, calculamos a média real:
            double cpuAverage = 0.0;
            if (totalSampledElapsed > 0)
            {
                // (Tempo total de CPU amostrado / Tempo total de amostragem) * 100
                // Multiplicamos por Environment.ProcessorCount para normalizar
                cpuAverage = (totalSampledCpuTime / totalSampledElapsed) * 100.0 / Environment.ProcessorCount;
            }


            // --- Resultados ---
            Console.WriteLine("\n========================================");
            Console.WriteLine("RESULTADOS");
            Console.WriteLine("========================================");
            Console.WriteLine($"Primos encontrados: {primes.Count}");
            Console.WriteLine($"Tempo de execução: {executionTime:F4} segundos");
            Console.WriteLine($"Memória utilizada: {memUsed:F2} MB");
            Console.WriteLine($"Uso médio de CPU: {cpuAverage:F2}%");
            Console.WriteLine("========================================");

            // SAÍDA CSV: tempo_segundos,memoria_mb,cpu_percent
            Console.WriteLine($"RESULTADO_CSV:{executionTime:F4},{memUsed:F2},{cpuAverage:F2}");
        }
    }
}