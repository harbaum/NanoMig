#include "ini_parser.h"
#include <iostream>
#include <fstream>
#include <sstream>

// Initialize global variables
std::string g_rom_path = "kick13.rom";
int g_screenshot_wait_time_seconds = 0;
int g_screenshot_wait_time_seconds_offset = 7; // seems Verilator Amiga takes longer to boot than vAmiga
bool g_screenshot_taken = false;
std::string g_screenshot_name = "";
std::string g_screenshot_dir = ".";  // Default to current directory
std::string g_adf_path = "df0.adf";
std::string g_config = "";
std::string g_chipset = "OCS"; // use OCS as default 


// Function to parse command-line arguments
void parse_command_line_args(int argc, char **argv) {
    for (int arg_pos = 1; arg_pos < argc; arg_pos++) {
        std::string arg = argv[arg_pos];

        // Check if the argument starts with "ini="
        if (arg.rfind("ini=", 0) == 0) {
            std::string config_file = arg.substr(4);
            std::cout << "Config file detected: " << config_file << std::endl;
            parse_ini_file(config_file);
        } 
        // Check if the argument starts with "screenshot_dir="
        else if (arg.rfind("screenshot_dir=", 0) == 0) {
            g_screenshot_dir = arg.substr(15);
            std::cout << "Screenshot directory detected: " << g_screenshot_dir << std::endl;
        }
    }
}

// Function to parse the INI file
void parse_ini_file(const std::string &file_path) {
    std::ifstream file(file_path);
    if (!file.is_open()) {
        std::cerr << "Failed to open .ini file: " << file_path << std::endl;
        return;
    }

    std::string line;
    while (std::getline(file, line)) {
        std::istringstream iss(line);
        std::string command;
        iss >> command;

        if (command == "regression") {
            std::string subcommand;
            iss >> subcommand;

            if (subcommand == "setup") {
                iss >> g_config >> g_rom_path;
                // Determine the chipset based on the configuration
                if (g_config.find("OCS") != std::string::npos) {
                    g_chipset = "OCS";
                } else if (g_config.find("ECS") != std::string::npos) {
                    g_chipset = "ECS";
                } else if (g_config.find("PLUS") != std::string::npos) {
                    g_chipset = "PLUS";
                }
            } else if (subcommand == "run") {
                iss >> g_adf_path;
            }
        } else if (command == "wait") {
            int time;
            std::string unit;
            if (iss >> time >> unit) {
                g_screenshot_wait_time_seconds = time;
            } else {
                std::cerr << "Error: Invalid format in wait command.\n";
            }
        } else if (command == "screenshot") {
            std::string subcommand;
            iss >> subcommand;

            if (subcommand == "save") {
                iss >> g_screenshot_name;
            }
        }
    }
    file.close();

    // Print the loaded values
    std::cout << "Loaded values from " << file_path << ":\n";
    std::cout << "Configuration: " << g_config << "\n";
    std::cout << "Chipset: " << g_chipset << "\n"; // Print the chipset value
    std::cout << "ROM Path: " << g_rom_path << "\n";
    std::cout << "ADF Path: " << g_adf_path << "\n";
    std::cout << "Wait Time: " << g_screenshot_wait_time_seconds << " seconds\n";
    std::cout << "Screenshot Name: " << g_screenshot_name << "\n";
}
