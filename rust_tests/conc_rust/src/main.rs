// Teste Concorrente: Multithreading (Threads Nativas)
// Este código deve ser colocado em 'conc_rust/src/main.rs'
use std::time::{Instant, Duration};
use std::sync::{Arc, Mutex};
use std::thread;
use std::sync::mpsc; // Módulo para comunicação entre threads

// Dependências de monitoramento
use sysinfo::{System, Process, Pid, ProcessRefreshKind};

// Parâmetros do Experimento
const LIMIT: u32 = 10000000; // Aumentado para 10 milhões para garantir tempo suficiente
const NUM_THREADS: usize = 8; // Número fixo de threads para padronização (Ajuste se necessário)
const MONITOR_INTERVAL_MS: u64 = 10;

// =================================================================
// ESTRUTURAS DE MONITORAMENTO INTERNO (sysinfo)
// (Mantidas as mesmas dos testes anteriores)
// =================================================================

pub struct ProcessMonitor {
    sys: System,
    pid: sysinfo::Pid,
}

impl ProcessMonitor {
    pub fn new() -> Result<Self, String> {
        let sys = System::new();
        let pid = sysinfo::get_current_pid().map_err(|e| format!("Falha ao obter PID: {}", e))?;
        Ok(Self { sys, pid })
    }

    pub fn get_memory_usage(&mut self) -> f64 {
        self.sys.refresh_process_specifics(self.pid, ProcessRefreshKind::new().with_memory());
        self.sys.process(self.pid).map(|p| p.memory() as f64 / 1024.0).unwrap_or(0.0)
    }

    pub fn get_cpu_usage(&mut self) -> f32 {
        self.sys.refresh_process_specifics(self.pid, ProcessRefreshKind::new().with_cpu());
        self.sys.process(self.pid).map(|p| p.cpu_usage()).unwrap_or(0.0)
    }
}

// =================================================================
// TAREFA CPU-BOUND (Compartilhada)
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

// Função executada por cada thread
fn worker_task(start: u32, end: u32, tx: mpsc::Sender<u32>) {
    for num in start..end {
        if is_prime(num) {
            // Se for primo, envia o resultado de volta para o canal principal
            tx.send(num).unwrap();
        }
    }
}

// =================================================================
// FUNÇÃO PRINCIPAL
// =================================================================

fn main() -> Result<(), String> {
    println!("{}", "=".repeat(60));
    println!("TESTE CONCORRENTE: THREADS NATIVAS");
    println!("{}", "=".repeat(60));
    println!("Linguagem: Rust (Multithreading)");
    println!("Limite: {} | Threads: {}", LIMIT, NUM_THREADS);
    println!("{}", "=".repeat(60));

    // 1. Inicializa o monitor e coleta a memória base
    let mut monitor = ProcessMonitor::new()?;
    let mem_before = monitor.get_memory_usage();

    // Configuração da thread de monitoramento (mantida inalterada)
    let cpu_samples = Arc::new(Mutex::new(Vec::<f32>::new()));
    let cpu_samples_clone = Arc::clone(&cpu_samples);
    let stop_signal = Arc::new(Mutex::new(false));
    let stop_signal_clone = Arc::clone(&stop_signal);

    // Inicia a thread de monitoramento
    let monitor_handle = thread::spawn(move || {
        let mut cpu_monitor = ProcessMonitor::new().expect("Falha ao iniciar monitor na thread.");
        let interval = Duration::from_millis(MONITOR_INTERVAL_MS);
        loop {
            thread::sleep(interval);
            if *stop_signal_clone.lock().unwrap() { break; }
            let cpu = cpu_monitor.get_cpu_usage();
            if cpu > 0.0 { cpu_samples_clone.lock().unwrap().push(cpu); }
        }
    });

    // --- Medição de tempo de execução ---
    println!("\nIniciando cálculo de primos concorrente...");
    let start_time = Instant::now();

    // Configuração da concorrência
    let chunk_size = LIMIT / NUM_THREADS as u32;
    let (tx, rx) = mpsc::channel(); // Cria um canal de comunicação (Sender, Receiver)
    let mut handles = vec![];

    // Cria e inicia as threads
    for i in 0..NUM_THREADS {
        let start = i as u32 * chunk_size + 2;
        let end = if i == NUM_THREADS - 1 { LIMIT } else { (i + 1) as u32 * chunk_size + 2 };
        let thread_tx = tx.clone();

        let handle = thread::spawn(move || {
            worker_task(start, end, thread_tx);
        });
        handles.push(handle);
    }
    // O Sender original pode ser dropado para sinalizar o fim da transmissão.
    drop(tx);

    // Coleta os resultados da thread principal
    let mut primes_count = 0;
    for _ in rx {
        primes_count += 1;
    }

    // Espera todas as threads worker terminarem (garantia)
    for handle in handles {
        handle.join().unwrap();
    }

    let execution_time = start_time.elapsed().as_secs_f64();

    // 2. Finaliza o monitoramento
    *stop_signal.lock().unwrap() = true;
    monitor_handle.join().unwrap();

    // 3. Coleta e calcula as métricas finais
    let mut final_monitor = ProcessMonitor::new()?;
    let mem_after = final_monitor.get_memory_usage();
    let mem_used = mem_after - mem_before;

    let cpu_average = {
        let samples = cpu_samples.lock().unwrap();
        if samples.is_empty() { 0.0 } else { samples.iter().sum::<f32>() / samples.len() as f32 }
    };

    // --- Resultados ---
    println!("\n{}", "=".repeat(60));
    println!("RESULTADOS");
    println!("{}", "=".repeat(60));
    println!("Números primos encontrados: {}", primes_count);
    println!("Tempo de execução: {:.4} segundos", execution_time);
    println!("Memória utilizada: {:.2} MB", mem_used);
    println!("Uso médio de CPU: {:.2}%", cpu_average);
    println!("{}", "=".repeat(60));

    // SAÍDA CSV: tempo_segundos,memoria_mb,cpu_percent
    println!("RESULTADO_CSV:{:.4},{:.2},{:.2}", execution_time, mem_used, cpu_average);

    Ok(())
}