export COMPOSE_PROJECT_NAME = workspace-devcontainer

COMPOSE = docker compose -f docker-compose.yml

# gate.yml 只调 `make check`；deploy.yml、rollback.yml 调 `make deploy`。
SHELLCHECK_IMAGE = koalaman/shellcheck:v0.10.0
HADOLINT_IMAGE = hadolint/hadolint:v2.12.0

.PHONY: check
check: ## 全部检查：shellcheck、docker compose 配置校验、hadolint
	@bash .autoteam/scripts/check-instruction-budget.sh
	@# 用 docker 跑，本机不需要安装 shellcheck / hadolint；文件走 stdin，不依赖 bind mount
	@set -e; for f in $$(find scripts dockerfiles -name '*.sh' | sort); do \
		echo "shellcheck $$f"; \
		docker run --rm -i $(SHELLCHECK_IMAGE) - < "$$f"; \
	done
	@# docker-compose.yml 引用了 .env，缺失时用示例文件占位（.env 已在 .gitignore）
	@[ -f .env ] || cp .env.sample .env
	$(COMPOSE) config -q
	@# DL3004：Dockerfile 里有意用 sudo，本任务不改镜像内容，先忽略
	docker run --rm -i $(HADOLINT_IMAGE) hadolint --failure-threshold error --ignore DL3004 - < Dockerfile
	docker run --rm -i $(HADOLINT_IMAGE) hadolint --failure-threshold error --ignore DL3004 - < dockerfiles/Dockerfile.java

.PHONY: dev
dev: ## 一条命令起环境，可重复执行：准备 .env 和数据目录，启动 app 与 Docker-in-Docker
	bash scripts/setup.sh
	$(COMPOSE) up -d app

.PHONY: deploy
deploy: ## 等本次提交的镜像构建（build-devcontainer*.yml）成功，构建成功即视为上线
	bash scripts/wait-build.sh "$$(git rev-parse HEAD)"

.PHONY: setup
setup:
	bash scripts/setup.sh

.PHONY: run
run:
	$(COMPOSE) up

.PHONY: start
start:
	$(COMPOSE) up -d

.PHONY: start-opencode
start-opencode: restart-opencode

.PHONY: restart-opencode
restart-opencode:
	$(COMPOSE) up -d opencode
	$(COMPOSE) restart opencode

.PHONY: logs
logs:
	$(COMPOSE) logs -f app

.PHONY: multica.status
multica.status:
	$(COMPOSE) exec multica multica daemon status --output json

.PHONY: multica.logs
multica.logs:
	$(COMPOSE) logs -f multica

.PHONY: multica.restart
multica.restart:
	$(COMPOSE) restart multica

.PHONY: multica.stop
multica.stop:
	$(COMPOSE) stop multica

.PHONY: multica.smoke
multica.smoke:
	$(COMPOSE) run --rm --no-deps multica multica version

.PHONY: agent-cli.smoke
agent-cli.smoke:
	$(COMPOSE) run --rm --no-deps multica smoke-agent-cli-launchers

.PHONY: restart
restart: stop start

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: bash
bash:
	$(COMPOSE) exec app bash

.PHONY: ssh
ssh:
	ssh -p 2222 ubuntu@localhost

.PHONY: update
update: pull down start

.PHONY: pull
pull:
	$(COMPOSE) pull

.PHONY: build
build:
	$(COMPOSE) build app

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: destroy
destroy:
	$(COMPOSE) down --volumes --rmi all

# ==== k3s 部署（deploy/ 目录，参考 yangcheng-team/eastar-price 的 deploy 目录风格） ====
# 需要本地 kubectl 已经指向目标集群（oracle-arm1），且已安装 kubeseal。

.PHONY: deploy.setup
deploy.setup: # 把当前 kubectl context 切到 devcontainer 命名空间
	kubectl config set-context --current --namespace=devcontainer

.PHONY: deploy.encode
deploy.encode: # 把明文 deploy/app-secret.yaml 加密成 deploy/app-sealed-secret.yaml
	kubeseal --format=yaml --cert=deploy/config/sealed-secret.crt < deploy/app-secret.yaml > deploy/app-sealed-secret.yaml

.PHONY: deploy.config
deploy.config: # 本地预览 kustomize 渲染结果，不实际 apply
	kubectl kustomize ./

.PHONY: deploy.apply
deploy.apply: # 应用 deploy/ 到集群
	kubectl apply -k ./
	kubectl rollout status deployment/app -n devcontainer --timeout=5m

.PHONY: deploy.status
deploy.status: # 查看当前部署状态
	kubectl get pods,svc,ingress,pvc -n devcontainer

.PHONY: deploy.logs
deploy.logs: # 查看 app 容器日志
	kubectl logs -n devcontainer -l app=devcontainer -c app -f

.PHONY: deploy.bash
deploy.bash: # 进入集群里的 app 容器
	kubectl exec -it -n devcontainer deployment/app -c app -- bash

.PHONY: deploy.ssh
deploy.ssh: # SSH 进云端实例
	ssh -p 2222 ubuntu@ai.hdgcs.com

.PHONY: deploy.multica-status
deploy.multica-status:
	kubectl exec -n devcontainer deployment/app -c multica -- multica daemon status --output json

.PHONY: deploy.multica-logs
deploy.multica-logs:
	kubectl logs -n devcontainer deployment/app -c multica -f
