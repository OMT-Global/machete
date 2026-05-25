PREFIX ?= /usr/local/bin
BINARY = machete
DIST   = dist/
DEST   = $(DIST)/$(BINARY)

.PHONY: all build install test clean

all: build test

build:
	@mkdir -p $(DIST)
	@echo "==> Building $(BINARY)..."
	@go build -o $(DEST) ./cmd/$(BINARY)
	@echo "==> Done: $(DEST)"

install: build
	@echo "==> Installing $(DEST) to $(PREFIX)..."
	@sudo cp $(DEST) $(PREFIX)/$(BINARY)
	@chmod 755 $(PREFIX)/$(BINARY)
	@echo "==> Installed: $(PREFIX)/$(BINARY)"

test:
	@echo "==> Running tests..."
	@go test -v -race -count=1 ./...

clean:
	@echo "==> Cleaning..."
	@rm -rf $(DIST)
	@echo "==> Done"
