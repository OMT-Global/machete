PREFIX ?= /usr/local/bin
BINARY = machete

.PHONY: all build install test clean

all: build test

build:
	@echo "==> Building $(BINARY)..."
	@go build -o $(BINARY) ./cmd/$(BINARY)
	@echo "==> Done: ./$(BINARY)"

install: build
	@echo "==> Installing $(BINARY) to $(PREFIX)..."
	@mkdir -p $(dir $(PREFIX))
	@sudo cp ./$(BINARY) $(PREFIX)/$(BINARY)
	@chmod 755 $(PREFIX)/$(BINARY)
	@echo "==> Installed: $(PREFIX)/$(BINARY)"

test:
	@echo "==> Running tests..."
	@go test -v -race -count=1 ./...

clean:
	@echo "==> Cleaning..."
	@rm -f $(BINARY)
	@rm -rf dist/
	@echo "==> Done"
