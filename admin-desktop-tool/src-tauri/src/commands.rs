use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
    sync::Mutex,
};

/* ============================================================
   Global guard to prevent concurrent script execution
   ============================================================ */
static SCRIPT_GUARD: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

/* ============================================================
   Persistent application configuration
   ============================================================ */
#[derive(Debug, Serialize, Deserialize)]
pub struct AppConfig {
    pub tools_dir: String,
    pub secrets_path: String,
    pub project_id: String,
}

/* ============================================================
   Config helpers (Tauri v2–safe, no tauri::api)
   ============================================================ */
fn config_path() -> Result<PathBuf, String> {
    // Use working directory for now (stable + predictable).
    let cwd = std::env::current_dir()
        .map_err(|e| format!("Unable to determine working directory: {}", e))?;
    Ok(cwd.join("ialfm_config.json"))
}

fn load_config() -> Result<AppConfig, String> {
    let path = config_path()?;
    let raw = fs::read_to_string(&path)
        .map_err(|_| "Setup has not been run yet".to_string())?;
    serde_json::from_str(&raw)
        .map_err(|e| format!("Invalid config file: {}", e))
}

/* ============================================================
   Commands exposed to the frontend
   ============================================================ */

/// Save setup configuration after validating inputs
#[tauri::command]
pub fn save_config(
    tools_dir: String,
    secrets_path: String,
    project_id: String,
) -> Result<(), String> {
    // Validate tools directory
    if !Path::new(&tools_dir).is_dir() {
        return Err(format!("Tools directory not found: {}", tools_dir));
    }

    // Validate secrets file exists
    if !Path::new(&secrets_path).is_file() {
        return Err(format!("Secrets JSON not found: {}", secrets_path));
    }

    // Read and validate secrets JSON
    let raw = fs::read_to_string(&secrets_path)
        .map_err(|e| format!("Failed to read secrets file: {}", e))?;

    let json: Value = serde_json::from_str(&raw)
        .map_err(|e| format!("Secrets file is not valid JSON: {}", e))?;

    // Validate Firebase service account structure
    let is_valid_service_account =
        json.get("type") == Some(&Value::String("service_account".into()))
            && json.get("project_id").is_some()
            && json.get("client_email").is_some()
            && json.get("private_key").is_some();

    if !is_valid_service_account {
        return Err(
            "Invalid Firebase service account JSON. Expected a Google service_account key file."
                .to_string(),
        );
    }

    // Persist configuration
    let cfg = AppConfig {
        tools_dir,
        secrets_path,
        project_id,
    };

    let path = config_path()?;
    let json = serde_json::to_string_pretty(&cfg)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;

    fs::write(&path, json)
        .map_err(|e| format!("Failed to write config file: {}", e))?;

    Ok(())
}

/// Run `npm install` in the selected tools directory
#[tauri::command]
pub fn run_npm_install(path: String) -> Result<String, String> {
    if !Path::new(&path).is_dir() {
        return Err(format!("Invalid directory: {}", path));
    }

    let output = Command::new("npm")
        .arg("install")
        .current_dir(&path)
        .output()
        .map_err(|e| format!("Failed to spawn npm: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

/// Write JSON to a file inside the tools directory
#[tauri::command]
pub fn write_json(path: String, data: String) -> Result<(), String> {
    let cfg = load_config()?;
    let target = Path::new(&cfg.tools_dir).join(&path);

    fs::write(&target, data)
        .map_err(|e| format!("Failed to write JSON file: {}", e))?;
    Ok(())
}

/* ============================================================
   ✅ ARGUMENT STRUCT (ROBUST FIX)
   Accepts *both* camelCase and snake_case
   ============================================================ */
#[derive(Deserialize)]
pub struct RunNodeScriptArgs {
    #[serde(alias = "scriptPath", alias = "script_path")]
    pub script_path: String,
    pub args: Option<Vec<String>>,
}

/// Run a Node.js script located inside the tools directory
#[tauri::command]
pub fn run_node_script(payload: RunNodeScriptArgs) -> Result<String, String> {
    let _guard = SCRIPT_GUARD
        .lock()
        .map_err(|_| "Script execution lock poisoned".to_string())?;

    let cfg = load_config()?;

    let script = Path::new(&cfg.tools_dir).join(&payload.script_path);
    if !script.exists() {
        return Err(format!("Script not found: {}", script.display()));
    }

    let mut cmd = Command::new("node");
    cmd.arg(&script);

    if let Some(a) = payload.args {
        cmd.args(a);
    }

    cmd.current_dir(&cfg.tools_dir)
        .env(
            "GOOGLE_APPLICATION_CREDENTIALS",
            &cfg.secrets_path,
        )
        .env(
            "GOOGLE_CLOUD_PROJECT",
            &cfg.project_id,
        );

    let output = cmd
        .output()
        .map_err(|e| format!("Failed to run node script: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    if output.status.success() {
        Ok(stdout)
    } else {
        Err(format!(
            "Node script failed:\n{}\n{}",
            stdout, stderr
        ))
    }
}
