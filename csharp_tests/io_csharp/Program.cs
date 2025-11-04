// Teste I/O-bound: Manipulação de Arquivo Grande (Leitura/Escrita)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Threading;

namespace Experimentacao
{
    public class IoBoundTest
    {
        // CRUCIAL: Aumentado para 4 GB para evitar o cache do OS (sem SUDO)
        private const int FILE_SIZE_MB = 4000; 
        private const int CHUNK_SIZE = 1024 * 1024; // 1 MB
        private const string FILENAME = "../io_test_data.bin"; // Coloca o arquivo de dados no diretório pai
        
        // Intervalo de monitoramento (reduzido para capturar picos de hash)
        private const int MONITOR_INTERVAL_MS = 10; 

        // =================================================================
        // ESTRUTURAS AUXILIARES
        // =================================================================

        public class CpuSample
        {
            public TimeSpan TotalProcessorTime { get; set; }
            public TimeSpan ElapsedTime { get; set; }
        }

        // =================================================================
        // TAREFA I/O-BOUND (Criação e Leitura/Hash)
        // =================================================================

        private static void CreateDummyFile()
        {
            long sizeBytes = (long)FILE_SIZE_MB * 1024 * 1024;

            if (File.Exists(FILENAME) && new FileInfo(FILENAME).Length == sizeBytes)
            {
                Console.WriteLine($"Arquivo '{FILENAME}' já existe com o tamanho correto ({FILE_SIZE_MB} MB).");
                return;
            }
            
            Console.WriteLine($"Criando arquivo dummy de {FILE_SIZE_MB} MB ({FILENAME})...");

            // Cria um buffer com um padrão simples
            byte[] data = Enumerable.Range(0, CHUNK_SIZE).Select(i => (byte)(i % 256)).ToArray();

            using (var fs = new FileStream(FILENAME, FileMode.Create, FileAccess.Write, FileShare.None, CHUNK_SIZE))
            {
                for (int i = 0; i < FILE_SIZE_MB; i++)
                {
                    fs.Write(data, 0, CHUNK_SIZE);
                }
                fs.Flush(true); // Garante que tudo foi escrito no disco
            }
            Console.WriteLine("Criação do arquivo concluída.");
        }

        private static (string hash, long totalBytes) ProcessFile()
        {
            long totalBytes = 0;
            // Usa SHA256 do C# (namespace System.Security.Cryptography)
            using (var sha256 = SHA256.Create())
            using (var fs = new FileStream(FILENAME, FileMode.Open, FileAccess.Read, FileShare.Read, CHUNK_SIZE))
            {
                byte[] buffer = new byte[CHUNK_SIZE];
                int bytesRead;

                while ((bytesRead = fs.Read(buffer, 0, CHUNK_SIZE)) > 0)
                {
                    // Operaçäo de CPU (Hash) no chunk
                    sha256.TransformBlock(buffer, 0, bytesRead, buffer, 0);
                    totalBytes += bytesRead;
                }

                // Finaliza o hash
                sha256.TransformFinalBlock(buffer, 0, 0);

                // Converte o hash resultante para string hexadecimal
                string hashString = BitConverter.ToString(sha256.Hash).Replace("-", "").ToLowerInvariant();

                return (hashString, totalBytes);
            }
        }

        // =================================================================
        // MONITORAMENTO (Reutiliza a lógica do CPU-bound)
        // =================================================================

        private static double GetMemoryUsageMB(Process process)
        {
            return process.WorkingSet64 / 1024.0 / 1024.0;
        }

        private static void MonitorResources(Process process, List<CpuSample> cpuSamples, ManualResetEventSlim stopSignal)
        {
            Stopwatch stopwatch = Stopwatch.StartNew();
            TimeSpan lastProcessorTime = process.TotalProcessorTime;
            
            while (!stopSignal.Wait(MONITOR_INTERVAL_MS))
            {
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
            // 1. Prepara o arquivo (Cria 4GB se não existir)
            CreateDummyFile();

            // 2. Inicialização do Monitoramento
            Process currentProcess = Process.GetCurrentProcess();
            double memBefore = GetMemoryUsageMB(currentProcess);

            List<CpuSample> cpuSamples = new List<CpuSample>();
            ManualResetEventSlim stopSignal = new ManualResetEventSlim(false);

            Thread monitorThread = new Thread(() => MonitorResources(currentProcess, cpuSamples, stopSignal));
            monitorThread.Start();

            // --- Execução da Tarefa I/O ---
            Console.WriteLine("========================================");
            Console.WriteLine("TESTE I/O-BOUND: C#");
            Console.WriteLine("Tamanho do Arquivo: " + FILE_SIZE_MB + " MB");
            Console.WriteLine("========================================");
            Console.WriteLine("\nProcessando arquivo...");

            Stopwatch stopwatch = Stopwatch.StartNew();
            
            var (finalHash, totalBytes) = ProcessFile();

            stopwatch.Stop();
            double executionTime = stopwatch.Elapsed.TotalSeconds;

            // 3. Finalização
            stopSignal.Set();
            monitorThread.Join();

            currentProcess.Refresh();
            double memAfter = GetMemoryUsageMB(currentProcess);
            double memUsed = memAfter - memBefore;

            // 4. Cálculo da Média de CPU
            double totalSampledCpuTime = cpuSamples.Sum(s => s.TotalProcessorTime.TotalMilliseconds);
            double totalSampledElapsed = cpuSamples.Sum(s => s.ElapsedTime.TotalMilliseconds); 

            double cpuAverage = 0.0;
            if (totalSampledElapsed > 0)
            {
                // Cálculo de uso de CPU normalizado (Total Cpu Time / Tempo Real Amostrado) * 100
                // Divide por Environment.ProcessorCount para obter a média de % de um único núcleo
                // Mas não deve ter a divisão por Environment.ProcessorCount para ter o uso total
                cpuAverage = (totalSampledCpuTime / totalSampledElapsed) * 100.0; 
                
                // NOTA: Para C#, o TotalProcessorTime já é a soma de todos os cores
                // Usamos o cálculo direto para obter o percentual de uso do processo no período
            }

            // --- Resultados ---
            Console.WriteLine("\n========================================");
            Console.WriteLine("RESULTADOS");
            Console.WriteLine("========================================");
            Console.WriteLine($"Bytes processados: {totalBytes / (1024 * 1024)} MB");
            Console.WriteLine($"Hash: {finalHash.Substring(0, 10)}...");
            Console.WriteLine($"Tempo de execução: {executionTime:F4} segundos");
            Console.WriteLine($"Memória utilizada: {memUsed:F2} MB");
            Console.WriteLine($"Uso médio de CPU: {cpuAverage:F2}%");
            Console.WriteLine("========================================");

            // SAÍDA CSV: tempo_segundos,memoria_mb,cpu_percent
            Console.WriteLine($"RESULTADO_CSV:{executionTime:F4},{memUsed:F2},{cpuAverage:F2}");
        }
    }
}