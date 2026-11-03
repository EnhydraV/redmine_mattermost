# Mattermost se compile en Go 1.26 : grpc, tiré par l'API plugin, ne compile pas encore en Go 1.27
export GOTOOLCHAIN ?= go1.26.7

GO ?= go
PLUGIN_ID := $(shell sed -n 's/^ *"id": "\(.*\)",$$/\1/p' plugin.json)
PLUGIN_VERSION := $(shell sed -n 's/^ *"version": "\(.*\)",$$/\1/p' plugin.json)
BUNDLE := dist/$(PLUGIN_ID)-$(PLUGIN_VERSION).tar.gz
GOFLAGS_BUILD := -trimpath -ldflags="-s -w"

.PHONY: all test build bundle clean

all: test bundle

test:
	$(GO) vet ./...
	$(GO) test ./...

build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS_BUILD) -o server/dist/plugin-linux-amd64 .
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GO) build $(GOFLAGS_BUILD) -o server/dist/plugin-linux-arm64 .

bundle: build
	rm -rf dist/bundle
	mkdir -p dist/bundle/$(PLUGIN_ID)/server
	cp plugin.json dist/bundle/$(PLUGIN_ID)/
	cp -r server/dist dist/bundle/$(PLUGIN_ID)/server/
	tar -C dist/bundle -czf $(BUNDLE) $(PLUGIN_ID)
	rm -rf dist/bundle
	@echo "Bundle: $(BUNDLE)"

clean:
	rm -rf dist server/dist
