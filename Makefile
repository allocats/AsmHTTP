AS = as
LD = ld
CC = clang

SRC_DIR = src
BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin

SERVER_SRC = $(SRC_DIR)/server.s
CLIENT_SRC = $(SRC_DIR)/client.s

SERVER_OBJ = $(BUILD_DIR)/server.o
CLIENT_OBJ = $(BUILD_DIR)/client.o

SERVER_BIN = $(BIN_DIR)/server
CLIENT_BIN = $(BIN_DIR)/client

ASFLAGS = --64

LDFLAGS = 

all: $(SERVER_BIN) $(CLIENT_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(SERVER_OBJ): $(SERVER_SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $(SERVER_SRC) -o $(SERVER_OBJ)

$(SERVER_BIN): $(SERVER_OBJ) | $(BIN_DIR)
	$(LD) $(LDFLAGS) $(SERVER_OBJ) -o $(SERVER_BIN)

$(CLIENT_OBJ): $(CLIENT_SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $(CLIENT_SRC) -o $(CLIENT_OBJ)

$(CLIENT_BIN): $(CLIENT_OBJ) | $(BIN_DIR)
	$(LD) $(LDFLAGS) $(CLIENT_OBJ) -o $(CLIENT_BIN)

server: $(SERVER_BIN)

client: $(CLIENT_BIN)

clean:
	rm -rf $(BUILD_DIR)

rebuild: clean all

run-server: $(SERVER_BIN)
	./$(SERVER_BIN)

run-client: $(CLIENT_BIN)
	./$(CLIENT_BIN)

help:
	@echo "ATCP - Assembly TCP Socket Implementation"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build both server and client (default)"
	@echo "  server     - Build server only"
	@echo "  client     - Build client only"
	@echo "  clean      - Remove build artifacts"
	@echo "  rebuild    - Clean and build all"
	@echo "  run-server - Build and run server"
	@echo "  run-client - Build and run client"
	@echo "  help       - Show this help message"

.PHONY: all server client clean rebuild run-server run-client help
