# Makefile

# Default source directory if SRC_DIR is not provided
#FALLBACK_DIR=~/vAmigaTS/Agnus/Blitter/bbusy
#FALLBACK_DIR=~/vAmigaTS/Agnus/Blitter/bltint
# maybe add wait_time_seconds_offset as parameter here?
# bbusy needs 6 seconds, bltint needs 7 seconds
FALLBACK_DIR=~/vAmigaTS/Agnus/Blitter/fill
# this command is run in the parent directory
SIMULATION_CMD=make run
# this directory is located in the parent directory
SCREENSHOT_DIR=$(CURDIR)/screenshots
KICK_PATH=../kick13.rom

# Use SRC_DIR if defined, otherwise fallback to FALLBACK_DIR
SRC_DIR ?= $(FALLBACK_DIR)

TMP_DIR=/tmp
PARENT_DIR=..

# Run make for each .ini file in the parent directory
run_all: collect_files
	@mkdir -p $(SCREENSHOT_DIR)  # Ensure the screenshots directory exists
	@echo "Running simulations for each .ini file..."
	@for ini in $(TMP_DIR)/*.ini; do \
		echo "Found .ini file: $$ini"; \
#		(cd $(PARENT_DIR) && make run INI=$$ini); \
		(cd $(PARENT_DIR) && $(SIMULATION_CMD) INI=$$ini SCREENSHOT_DIR=$(SCREENSHOT_DIR)); \
	done
	
# Collect all .ini and .adf files from the specified directory
collect_files:
	@echo "Collecting .ini and .adf files from $(SRC_DIR)..."
	@mkdir -p $(TMP_DIR)  # Ensure the temporary directory exists
	@-find $(SRC_DIR) -name "*.ini" -exec cp {} $(TMP_DIR) \; || echo "No .ini files found."
	@-find $(SRC_DIR) -name "*.adf" -exec cp {} $(TMP_DIR) \; || echo "No .adf files found."
	@echo "Files collected in $(TMP_DIR):"
	@echo "Copying kick13.rom to $(TMP_DIR)..."
	@cp $(KICK_PATH) $(TMP_DIR) || echo "$(KICK_PATH) not found."
	@ls $(TMP_DIR)

# Clean up the temporary directory
clean:
	@echo "Cleaning up..."
	@rm -rf $(TMP_DIR)
	@make clean

# Default target
all: run_all

# End of Makefile
