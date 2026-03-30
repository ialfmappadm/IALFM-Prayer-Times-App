#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;

use tauri::{generate_context, generate_handler};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_log::Builder::default().build())

        .invoke_handler(generate_handler![
            commands::save_config,
            commands::run_npm_install,
            commands::write_json,
            commands::run_node_script
        ])

        .run(generate_context!())
        .expect("error while running tauri application");
}