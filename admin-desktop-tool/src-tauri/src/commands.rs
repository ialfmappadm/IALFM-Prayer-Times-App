use once_cell::sync::Lazy;
use serde::Deserialize;
use std::{
    fs,
    path::PathBuf,
    process::Command,
    sync::Mutex,
};

static SCRIPT_GUARD: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

/// Dev/admin-time announce tools folder:
/// <repo>/src-tauri/tools/announce
fn announce_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tools")
        .join("announce")
}

#[derive(Debug, Deserialize)]
pub struct RunNodeScriptPayload {
    #[serde(rename = "scriptPath")]
    pub script_path: String,
    pub args: Option<Vec<String>>,
    pub secrets_path: Option<String>,
    pub project_id: Option<String>,
}

#[tauri::command]
pub fn get_announce_dir() -> Result<String, String> {
    Ok(announce_dir().display().to_string())
}

#[tauri::command]
pub fn check_node_toolchain() -> Result<String, String> {
    let node_out = Command::new("node")
        .arg("--version")
        .output()
        .map_err(|e| format!("Node.js not found on PATH: {}", e))?;

    if !node_out.status.success() {
        return Err(format!(
            "Node.js check failed:\n{}",
            String::from_utf8_lossy(&node_out.stderr)
        ));
    }

    let npm_out = Command::new("npm")
        .arg("--version")
        .output()
        .map_err(|e| format!("npm not found on PATH: {}", e))?;

    if !npm_out.status.success() {
        return Err(format!(
            "npm check failed:\n{}",
            String::from_utf8_lossy(&npm_out.stderr)
        ));
    }

    Ok(format!(
        "node: {}\nnpm: {}",
        String::from_utf8_lossy(&node_out.stdout).trim(),
        String::from_utf8_lossy(&npm_out.stdout).trim()
    ))
}

#[tauri::command]
pub fn run_npm_install() -> Result<String, String> {
    let dir = announce_dir();

    let out = Command::new("npm")
        .arg("install")
        .current_dir(&dir)
        .output()
        .map_err(|e| format!("npm install failed in {}: {}", dir.display(), e))?;

    if !out.status.success() {
        let code = out
            .status
            .code()
            .map(|c| c.to_string())
            .unwrap_or_else(|| "terminated by signal".to_string());

        return Err(format!(
            "npm install failed in {}\nexit code: {}\n{}",
            dir.display(),
            code,
            String::from_utf8_lossy(&out.stderr)
        ));
    }

    Ok(format!(
        "cwd: {}\n{}",
        dir.display(),
        String::from_utf8_lossy(&out.stdout)
    ))
}

#[tauri::command]
pub fn write_json(path: String, data: String) -> Result<(), String> {
    let dir = announce_dir();
    let full_path = dir.join(path);

    fs::write(&full_path, data)
        .map_err(|e| format!("Failed to write {}: {}", full_path.display(), e))
}

#[tauri::command]
pub fn run_node_script(payload: RunNodeScriptPayload) -> Result<String, String> {
    let _guard = SCRIPT_GUARD.lock().unwrap();

    let dir = announce_dir();
    let script = dir.join(&payload.script_path);

    if !script.exists() {
        return Err(format!("Script not found: {}", script.display()));
    }

    let mut cmd = Command::new("node");
    cmd.arg(&script);

    if let Some(args) = payload.args {
        cmd.args(args);
    }

    if let Some(secrets) = payload.secrets_path {
        cmd.env("GOOGLE_APPLICATION_CREDENTIALS", &secrets);
    }

    if let Some(project) = payload.project_id {
        cmd.env("GOOGLE_CLOUD_PROJECT", &project);
    }

    let out = cmd
        .current_dir(&dir)
        .output()
        .map_err(|e| format!("Node execution failed in {}: {}", dir.display(), e))?;

    if !out.status.success() {
        let code = out
            .status
            .code()
            .map(|c| c.to_string())
            .unwrap_or_else(|| "terminated by signal".to_string());

        return Err(format!(
            "script: {}\ncwd: {}\nexit code: {}\n{}",
            script.display(),
            dir.display(),
            code,
            String::from_utf8_lossy(&out.stderr)
        ));
    }

    Ok(format!(
        "script: {}\ncwd: {}\n{}",
        script.display(),
        dir.display(),
        String::from_utf8_lossy(&out.stdout)
    ))
}