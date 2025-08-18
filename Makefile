AS = as
LD = ld

ASFLAGS = --64 -msyntax=intel 

SRC_DIR = src
BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin

SERVER_SRC = $(SRC_DIR)/server.asm
SERVER_OBJ = $(BUILD_DIR)/server.o
SERVER_BIN = $(BIN_DIR)/server

TEST_SRC = $(SRC_DIR)/parse_request.asm
TEST_OBJ= $(BUILD_DIR)/parse_request.o
TEST_BIN = $(BIN_DIR)/parse_request

all: $(SERVER_BIN) 

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(SERVER_OBJ): $(SERVER_SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $(SERVER_SRC) -o $(SERVER_OBJ)

$(SERVER_BIN): $(SERVER_OBJ) | $(BIN_DIR)
	$(LD) $(SERVER_OBJ) -o $(SERVER_BIN)

$(TEST_OBJ): $(TEST_SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $(TEST_SRC) -o $(TEST_OBJ)

$(TEST_BIN): $(TEST_OBJ) | $(BIN_DIR)
	$(LD) $(TEST_OBJ) -o $(TEST_BIN)

server: $(SERVER_BIN)

test: $(TEST_BIN)

clean:
	rm -rf $(BUILD_DIR)

rebuild: clean all

run-server: $(SERVER_BIN)
	./$(SERVER_BIN)

run-test: $(TEST_BIN)
	./$(TEST_BIN)

help:
	@echo "ATCP - Assembly TCP Socket Implementation"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build server (default)"
	@echo "  server     - Build server only"
	@echo "  clean      - Remove build artifacts"
	@echo "  rebuild    - Clean and build all"
	@echo "  run-server - Build and run server"
	@echo "  help       - Show this help message"

.PHONY: all server test clean rebuild run-server run-test help
