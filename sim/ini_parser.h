#pragma once

#include <string>

// External variables to hold configuration data
extern std::string g_rom_path;
extern int g_screenshot_wait_time_seconds;
extern int g_screenshot_wait_time_seconds_offset;
extern bool g_screenshot_taken;
extern std::string g_screenshot_name;
extern std::string g_adf_path;
extern std::string g_screenshot_dir;

// Functions to parse command-line arguments and INI files
void parse_command_line_args(int argc, char **argv);
void parse_ini_file(const std::string &file_path);
