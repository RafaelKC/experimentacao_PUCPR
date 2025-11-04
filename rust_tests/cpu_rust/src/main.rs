// Teste CPU-bound: Cálculo de Números Primos
// Experimento de Avaliação de Desempenho de Linguagens
use std::time::{Instant, Duration};
use std::sync::{Arc, Mutex};
use std::thread;

// Dependências de monitoramento
// Versão 0.30+ - Garante a importação de todos os tipos necessários
use sysinfo::{
    System,
    Process,
    Pid,
    ProcessRefreshKind,
    CpuRefreshKind
};

// CRUCIAL: Aumentar o limite para que o teste dure o suficiente (1-2s)
// para que o monitor de CPU colete amostras válidas.
const LIMIT: u32 = 5000000; // Aumentado para 5 milhões (Ajuste se ainda for muito rápido)
const MONITOR_INTERVAL_MS: u64 = 100; // Intervalo de coleta de CPU/Memória

// =================================================================
// ESTRUTURAS DE MONITORAMENTO INTERNO (sysinfo)
// =================================================================

// Estrutura para gerenciar a coleta de métricas do processo atual
pub struct ProcessMonitor {
    sys: System,
    pid: sysinfo::Pid,
}

impl ProcessMonitor {
    pub fn new() -> Result<Self, String> {
        // Inicializa o System sem carregar dados globais para ser mais rápido
        let sys = System::new();

        let pid = sysinfo::get_current_pid().map_err(|e| format!("Falha ao obter PID: {}", e))?;

        Ok(Self { sys, pid })
    }

    // Coleta a memória atual (RSS - Resident Set Size) em MB
    pub fn get_memory_usage(&mut self) -> f64 {
        // Refresca apenas a informação de memória do processo atual
        self.sys.refresh_process_specifics(self.pid, ProcessRefreshKind::new().with_memory());

        // sysinfo retorna a memória em KiB, dividimos por 1024 para obter MB
        self.sys.process(self.pid).map(|p| p.memory() as f64 / 1024.0).unwrap_or(0.0)
    }

    // Coleta a porcentagem de uso de CPU do processo desde o último refresh
    pub fn get_cpu_usage(&mut self) -> f32 {
        // Refresca apenas a informação de CPU do processo atual
        self.sys.refresh_process_specifics(self.pid, ProcessRefreshKind::new().with_cpu());

        // sysinfo retorna a porcentagem
        self.sys.process(self.pid).map(|p| p.cpu_usage()).unwrap_or(0.0)
    }
}

// =================================================================
// TAREFA CPU-BOUND (Mantida inalterada)
// =================================================================

fn is_prime(n: u32) -> bool {
    if n < 2 { return false; }
    if n == 2 { return true; }
    if n % 2 == 0 { return false; }
    let limit = (n as f64).sqrt() as u32;
    for i in (3..=limit).step_by(2) {
        if n % i == 0 { return false; }
    }
    true
}

fn calculate_primes(limit: u32) -> Vec<u32> {
    let mut primes = Vec::new();
    for num in 2..limit {
        if is_prime(num) {
            primes.push(num);
        }
    }
    primes
}

// =================================================================
// FUNÇÃO PRINCIPAL
// =================================================================

fn main() -> Result<(), String> {
    println!("{}", "=".repeat(60));
    println!("TESTE CPU-BOUND: CÁLCULO DE NÚMEROS PRIMOS");
    println!("{}", "=".repeat(60));
    println!("Linguagem: Rust (com sysinfo)");
    println!("Limite: {}", LIMIT);
    println!("{}", "=".repeat(60));

    // 1. Inicializa o monitor e coleta a memória base
    let mut initial_monitor = ProcessMonitor::new()?;
    let mem_before = initial_monitor.get_memory_usage();

    // Configuração da thread de monitoramento
    let cpu_samples = Arc::new(Mutex::new(Vec::<f32>::new()));
    let cpu_samples_clone = Arc::clone(&cpu_samples);
    let stop_signal = Arc::new(Mutex::new(false));
    let stop_signal_clone = Arc::clone(&stop_signal);

    // Inicia a thread de monitoramento de CPU (polling)
    let monitor_handle = thread::spawn(move || {
        let mut cpu_monitor = ProcessMonitor::new().expect("Falha ao iniciar monitor na thread.");
        let interval = Duration::from_millis(MONITOR_INTERVAL_MS);

        loop {
            // Dorme um pouco para dar tempo ao SO calcular a variação de CPU
            thread::sleep(interval);

            // Verifica o sinal antes da coleta final
            if *stop_signal_clone.lock().unwrap() {
                break;
            }

            let cpu = cpu_monitor.get_cpu_usage();

            // Registra a amostra (ignora 0.0, que geralmente é a primeira amostra ou erro)
            if cpu > 0.0 {
                cpu_samples_clone.lock().unwrap().push(cpu);
            }
        }
    });

    // --- Medição de tempo de execução ---
    println!("\nCalculando números primos até {}...", LIMIT);
    let start_time = Instant::now();

    // Execução da tarefa CPU-bound
    let primes = calculate_primes(LIMIT);

    let execution_time = start_time.elapsed().as_secs_f64();

    // 2. Sinaliza a thread de monitoramento para parar e aguarda sua conclusão
    *stop_signal.lock().unwrap() = true;
    monitor_handle.join().unwrap();

    // 3. Coleta e calcula as métricas finais
    // Coletamos a memória novamente
    let mut final_monitor = ProcessMonitor::new()?;
    let mem_after = final_monitor.get_memory_usage();

    // Calcula a diferença de memória usada pelo cálculo
    let mem_used = mem_after - mem_before;

    // Calcula a média das amostras de CPU
    let cpu_average = {
        let samples = cpu_samples.lock().unwrap();
        if samples.is_empty() {
            0.0
        } else {
            // Soma todas as amostras e divide pelo número de amostras
            samples.iter().sum::<f32>() / samples.len() as f32
        }
    };

    // --- Resultados ---
    println!("\n{}", "=".repeat(60));
    println!("RESULTADOS");
    println!("{}", "=".repeat(60));
    println!("Números primos encontrados: {}", primes.len());
    println!("Tempo de execução: {:.4} segundos", execution_time);
    println!("Memória utilizada: {:.2} MB", mem_used);
    println!("Uso médio de CPU: {:.2}%", cpu_average);
    println!("{}", "=".repeat(60));

    // SAÍDA CSV: Última linha de stdout para captura pelo script shell
    // Formato: tempo_segundos,memoria_mb,cpu_percent
    println!("RESULTADO_CSV:{:.4},{:.2},{:.2}", execution_time, mem_used, cpu_average);

    Ok(())
}