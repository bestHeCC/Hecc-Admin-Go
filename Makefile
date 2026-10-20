.PHONY: help dev-server dev-web build build-server build-web test lint tidy

help: ## 显示可用命令
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

dev-server: ## 启动后端（需先准备好 configs/config.yaml）
	cd server && go run ./cmd/server

dev-web: ## 启动前端开发服务器
	cd web && npm run dev

build: build-server build-web ## 构建前后端

build-server: ## 构建后端
	cd server && go build ./...

build-web: ## 构建前端
	cd web && npm run build

test: ## 运行后端测试
	cd server && go test ./...

lint: ## 运行后端 vet 与前端 lint
	cd server && go vet ./...
	cd web && npm run lint

tidy: ## 整理 Go 依赖
	cd server && go mod tidy
