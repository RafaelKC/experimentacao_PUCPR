// Teste I/O-bound: Manipulação de Arquivo Grande (Leitura/Escrita)
// Este código deve ser colocado em 'io_rust/src/main.rs'
use std::time::{Instant, Duration};
use std::fs::File;
use std::io::{self, Read, Write};
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::thread;

use sha2::{Digest, Sha256};
use hex;

// Dependências de monitoramento
use sysinfo::{
    System,
    Process,
    Pid,
    ProcessRefreshKind,
    CpuRefreshKind
};


// Parâmetros do Experimento
const FILE_SIZE_MB: usize = 4000;
const CHUNK_SIZE: usize = 1024 * 1024; // 1 MB
const FILENAME: &str = "../io_test_data.bin"; // Arquivo de dados no diretório pai
const MONITOR_INTERVAL_MS: u64 = 10; // Intervalo de coleta de CPU/Memória

// =================================================================
// ESTRUTURAS DE MONITORAMENTO INTERNO (sysinfo)
// (Mantidas as mesmas do teste CPU-bound)
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
// TAREFA I/O-BOUND
// =================================================================

fn create_dummy_file() -> io::Result<()> {
    let size_bytes = FILE_SIZE_MB * 1024 * 1024;
    let file_path = Path::new(FILENAME);

    if file_path.exists() && file_path.metadata()?.len() as usize == size_bytes {
        println!("Arquivo '{}' já existe com o tamanho correto ({} MB).", FILENAME, FILE_SIZE_MB);
        return Ok(());
    }

    println!("Criando arquivo dummy de {} MB ({})...", FILE_SIZE_MB, FILENAME);

    let mut file = File::create(file_path)?;
    let data: Vec<u8> = (0..CHUNK_SIZE).map(|i| (i % 256) as u8).collect();

    for _ in 0..FILE_SIZE_MB {
        file.write_all(&data)?;
    }

    file.sync_all()?;
    println!("Criação do arquivo concluída.");
    Ok(())
}

fn process_file() -> io::Result<(String, usize)> {
    let mut total_bytes = 0;
    let mut hasher = Sha256::new();
    let mut buffer = vec![0; CHUNK_SIZE];

    let mut file = File::open(FILENAME)?;

    loop {
        // Operação I/O: leitura do arquivo
        let bytes_read = file.read(&mut buffer)?;

        if bytes_read == 0 {
            break;
        }

        // Processamento de CPU (hash)
        hasher.update(&buffer[..bytes_read]);
        total_bytes += bytes_read;
    }

    let final_hash = hex::encode(hasher.finalize());
    Ok((final_hash, total_bytes))
}

// =================================================================
// FUNÇÃO PRINCIPAL
// =================================================================

fn main() -> Result<(), String> {

    println!("{}", "=".repeat(60));
    println!("TESTE I/O-BOUND: MANIPULAÇÃO DE ARQUIVOS");
    println!("{}", "=".repeat(60));
    println!("Linguagem: Rust (com sysinfo)");
    println!("Tamanho do Arquivo: {} MB", FILE_SIZE_MB);
    println!("{}", "=".repeat(60));

    // 1. Prepara o arquivo
    create_dummy_file().map_err(|e| format!("Erro IO ao criar arquivo: {}", e))?;

    // 2. Inicializa o monitor e coleta a memória base
    let mut initial_monitor = ProcessMonitor::new()?;
    let mem_before = initial_monitor.get_memory_usage();

    // Configuração da thread de monitoramento
    let cpu_samples = Arc::new(Mutex::new(Vec::<f32>::new()));
    let cpu_samples_clone = Arc::clone(&cpu_samples);
    let stop_signal = Arc::new(Mutex::new(false));
    let stop_signal_clone = Arc::clone(&stop_signal);

    // Inicia a thread de monitoramento de CPU
    let monitor_handle = thread::spawn(move || {
        let mut cpu_monitor = ProcessMonitor::new().expect("Falha ao iniciar monitor na thread.");
        let interval = Duration::from_millis(MONITOR_INTERVAL_MS);

        loop {
            thread::sleep(interval);

            if *stop_signal_clone.lock().unwrap() {
                break;
            }

            let cpu = cpu_monitor.get_cpu_usage();

            // Registra a amostra
            if cpu > 0.0 {
                cpu_samples_clone.lock().unwrap().push(cpu);
            }
        }
    });

    // --- Medição de tempo de execução ---
    println!("\nProcessando arquivo '{}'...", FILENAME);
    let start_time = Instant::now();

    // Execução da tarefa I/O-bound
    let (final_hash, total_bytes) = process_file().map_err(|e| format!("Erro IO ao processar: {}", e))?;

    let execution_time = start_time.elapsed().as_secs_f64();

    // 3. Sinaliza a thread de monitoramento para parar e aguarda sua conclusão
    *stop_signal.lock().unwrap() = true;
    monitor_handle.join().unwrap();

    // 4. Coleta e calcula as métricas finais
    let mut final_monitor = ProcessMonitor::new()?;
    let mem_after = final_monitor.get_memory_usage();

    let mem_used = mem_after - mem_before;

    let cpu_average = {
        let samples = cpu_samples.lock().unwrap();
        if samples.is_empty() {
            0.0
        } else {
            samples.iter().sum::<f32>() / samples.len() as f32
        }
    };

    // --- Resultados ---
    println!("\n{}", "=".repeat(60));
    println!("RESULTADOS");
    println!("{}", "=".repeat(60));
    println!("Bytes processados: {} MB", total_bytes / (1024 * 1024));
    println!("Hash do processamento: {}...", &final_hash[..10]);
    println!("Tempo de execução: {:.4} segundos", execution_time);
    println!("Memória utilizada: {:.2} MB", mem_used);
    println!("Uso médio de CPU: {:.2}%", cpu_average);
    println!("{}", "=".repeat(60));

    // SAÍDA CSV: Última linha de stdout para captura pelo script shell
    // Formato: tempo_segundos,memoria_mb,cpu_percent
    println!("RESULTADO_CSV:{:.4},{:.2},{:.2}", execution_time, mem_used, cpu_average);

    Ok(())
}