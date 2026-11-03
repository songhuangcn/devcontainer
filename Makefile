export COMPOSE_PROJECT_NAME = workspace-devcontainer

COMPOSE = docker compose -f docker-compose.yml
SHELL = /bin/bash
.SHELLFLAGS = -eu -o pipefail -c

# .github/workflows/autoteam.yml 在 PR 上只调 `make check`，合并后调 `make deploy`（autoteam 的成员仓库约定）。
SHELLCHECK_IMAGE = koalaman/shellcheck:v0.10.0
HADOLINT_IMAGE = hadolint/hadolint:v2.12.0

.PHONY: check
check: ## 脚本/Dockerfile 检查、Compose/Kustomize 校验、运行时脚本测试
	@# 用 docker 跑，本机不需要安装 shellcheck / hadolint；文件走 stdin，不依赖 bind mount
	@set -e; for f in $$(find scripts -name '*.sh' | sort); do \
		echo "shellcheck $$f"; \
		docker run --rm -i $(SHELLCHECK_IMAGE) - < "$$f"; \
	done
	@# docker-compose.yml 引用了 .env，缺失时用示例文件占位（.env 已在 .gitignore）
	@[ -f .env ] || cp .env.sample .env
	$(COMPOSE) config -q
	docker run --rm -i $(HADOLINT_IMAGE) hadolint --failure-threshold error - < Dockerfile
	$(MAKE) test
	$(MAKE) deploy.config > /dev/null

.PHONY: dev
dev: ## 准备配置和数据目录，启动 SSH 工作容器
	bash scripts/setup.sh
	$(COMPOSE) up -d app

.PHONY: deploy
deploy: ## 等本次提交的主镜像构建与部署成功
	bash scripts/wait-build.sh "$$(git rev-parse HEAD)"

.PHONY: setup
setup:
	bash scripts/setup.sh

.PHONY: install
install: dev ## 在已启动容器中安装/更新用户工具，安装脚本无需重建镜像
	$(COMPOSE) exec -T app bash /workspace/.devcontainer/scripts/install.sh

.PHONY: test
test: ## 在主镜像中验证入口和安装脚本（不下载工具、不接触真实 data）
	tar -cf - scripts config agents | \
		docker run --rm -i --entrypoint bash $${IMAGE_NAME:-songhuangcn/devcontainer}:$${IMAGE_TAG:-latest} \
		-c 'root=$$(mktemp -d); tar -xf - -C "$$root"; bash "$$root/scripts/test-runtime.sh"'

.PHONY: install.test
install.test: ## 在隔离容器中验证真实安装；脚本和配置通过 stdin 提供，不进入镜像
	tar -cf - scripts config agents | \
		docker run --rm -i --entrypoint bash $${IMAGE_NAME:-songhuangcn/devcontainer}:$${IMAGE_TAG:-latest} \
		-eu -o pipefail -c 'root=$$(mktemp -d); tar -xf - -C "$$root"; \
		bash "$$root/scripts/entrypoint.sh"; \
		bash "$$root/scripts/install.sh"; export PATH="$$HOME/.local/bin:$$PATH"; \
		cd /tmp; mise exec -- docker compose version; \
		mise exec -- python -c "import defusedxml, jsonschema, numpy, pypdf, pymupdf, yaml, requests, ruamel.yaml, urllib3"; \
		mise settings set jobs 2; grep -q "jobs = 2" "$$root/config/mise.toml"; \
		test -r "$$HOME/.claude/CLAUDE.md"; test -d "$$HOME/.claude/skills"'

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
	$(COMPOSE) exec multica /home/ubuntu/.local/bin/multica daemon status --output json

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
	$(COMPOSE) exec -T app /home/ubuntu/.local/bin/multica version

.PHONY: agent-cli.smoke
agent-cli.smoke:
	$(COMPOSE) exec -T app bash -lc 'exec mise exec -- bash /workspace/.devcontainer/scripts/smoke-agent-cli-launchers.sh'

.PHONY: restart
restart: stop start

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: bash
bash:
	$(COMPOSE) exec app bash -lc 'exec mise exec -- bash'

.PHONY: ssh
ssh:
	ssh -p 2222 ubuntu@localhost

.PHONY: update
update:
	$(MAKE) pull
	$(MAKE) down
	$(MAKE) install
	$(MAKE) start

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
	kubectl kustomize deploy/ --load-restrictor LoadRestrictionsNone

.PHONY: deploy.apply
deploy.apply: # 应用 deploy/ 到集群
	kubectl kustomize deploy/ --load-restrictor LoadRestrictionsNone | kubectl apply -f -
	kubectl rollout status deployment/app -n devcontainer --timeout=20m

.PHONY: deploy.status
deploy.status: # 查看当前部署状态
	kubectl get pods,svc,ingress,pvc -n devcontainer

.PHONY: deploy.logs
deploy.logs: # 查看 app 容器日志
	kubectl logs -n devcontainer -l app=devcontainer -c app -f

.PHONY: deploy.bash
deploy.bash: # 进入集群里的 app 容器
	kubectl exec -it -n devcontainer deployment/app -c app -- bash -lc 'exec mise exec -- bash'

.PHONY: deploy.ssh
deploy.ssh: # SSH 进云端实例
	ssh -p 2222 ubuntu@ai.hdgcs.com

.PHONY: deploy.multica-status
deploy.multica-status:
	kubectl exec -n devcontainer deployment/app -c multica -- /home/ubuntu/.local/bin/multica daemon status --output json

.PHONY: deploy.multica-logs
deploy.multica-logs:
	kubectl logs -n devcontainer deployment/app -c multica -f
