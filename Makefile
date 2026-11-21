export COMPOSE_PROJECT_NAME = workspace-devcontainer

COMPOSE = docker compose -f docker-compose.yml
INSTALL_TOOLS = $(COMPOSE) run --rm --no-deps --pull never -T opencode bash /workspace/.devcontainer/scripts/install.sh
SHELL = /bin/bash
.SHELLFLAGS = -eu -o pipefail -c

# .github/workflows/autoteam.yml 在 PR 上只调 `make check`，合并后调 `make deploy`（autoteam 的成员仓库约定）。
SHELLCHECK_IMAGE = koalaman/shellcheck:v0.10.0
HADOLINT_IMAGE = hadolint/hadolint:v2.12.0

.PHONY: check
check: ## 脚本/Dockerfile 检查、Compose/Kustomize 校验、运行时脚本测试
	@# 用 docker 跑，本机不需要安装 shellcheck / hadolint；文件走 stdin，不依赖 bind mount
	@set -e; for f in $$(find scripts tests -name '*.sh' | sort); do \
		echo "shellcheck $$f"; \
		docker run --rm -i $(SHELLCHECK_IMAGE) - < "$$f"; \
	done
	WORKSPACE_COMPOSE_ENV_FILE=.env.sample $(COMPOSE) --env-file .env.sample config -q
	docker run --rm -i $(HADOLINT_IMAGE) hadolint --failure-threshold error - < Dockerfile
	$(MAKE) test
	$(MAKE) deploy.config > /dev/null

.PHONY: deploy
deploy: ## 等本次提交的主镜像构建与部署成功
	bash scripts/wait-build.sh "$$(git rev-parse HEAD)"

.PHONY: setup
setup: prepare-local ## 构建应用镜像、准备 Docker 镜像并安装工具，不启动服务
	$(MAKE) build
	$(COMPOSE) pull --policy missing docker
	$(INSTALL_TOOLS) --local-setup

.PHONY: prepare-local
prepare-local:
	bash scripts/setup.sh

.PHONY: install
install: prepare-local ## 仅安装/更新用户工具，不重新构建镜像
	$(INSTALL_TOOLS)

.PHONY: test
test: ## 在主镜像中验证入口、安装脚本和安装命令编排（不下载工具、不接触真实 data）
test: TEST_SCRIPT = test-runtime.sh

.PHONY: install.test
install.test: ## 在隔离容器中验证真实安装；脚本和配置通过 stdin 提供，不进入镜像
install.test: TEST_SCRIPT = test-install.sh

test install.test:
	tar -cf - Makefile scripts tests config agents | \
		docker run --rm -i --entrypoint bash $${IMAGE_NAME:-songhuangcn/devcontainer}:$${IMAGE_TAG:-latest} \
		-eu -o pipefail -c 'root=$$(mktemp -d); tar -xf - -C "$$root"; \
		bash "$$root/tests/$(TEST_SCRIPT)"'

.PHONY: run
run:
	$(COMPOSE) up --remove-orphans

.PHONY: start
start:
	$(COMPOSE) up -d --no-build --pull never --remove-orphans

.PHONY: start-opencode
start-opencode: restart-opencode

.PHONY: restart-opencode
restart-opencode:
	$(COMPOSE) up -d opencode
	$(COMPOSE) restart opencode

.PHONY: logs
logs:
	$(COMPOSE) logs -f opencode

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
	$(COMPOSE) exec -T multica /home/ubuntu/.local/bin/multica version

.PHONY: agent-cli.smoke
agent-cli.smoke:
	$(COMPOSE) exec -T multica bash -lc 'exec mise exec -- bash /workspace/.devcontainer/tests/smoke-agent-cli-launchers.sh'

.PHONY: restart
restart: stop start

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: bash
bash:
	$(COMPOSE) exec opencode bash -lc 'exec mise exec -- bash'

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
	$(COMPOSE) build opencode

.PHONY: down
down:
	$(COMPOSE) down --remove-orphans

.PHONY: destroy
destroy:
	$(COMPOSE) down --remove-orphans --volumes --rmi all

# ==== k3s 部署（deploy/ 目录，参考 yangcheng-team/eastar-price 的 deploy 目录风格） ====
# 需要本地 kubectl 已经指向目标集群（oracle-arm1），且已安装 kubeseal。

RUNTIME_REVISION ?= $(shell git rev-parse HEAD)

.PHONY: deploy.setup
deploy.setup: # 在替换应用 Pod 之前，准备持久化工作区
	$(MAKE) --no-print-directory deploy.config | bash scripts/deploy-setup.sh

.PHONY: deploy.encode
deploy.encode: # 把明文 deploy/app-secret.yaml 加密成 deploy/app-sealed-secret.yaml
	kubeseal --format=yaml --cert=deploy/config/sealed-secret.crt < deploy/app-secret.yaml > deploy/app-sealed-secret.yaml

.PHONY: deploy.config
deploy.config: # 本地预览 kustomize 渲染结果，不实际 apply
	@set -e; revision='$(RUNTIME_REVISION)'; \
	[[ "$$revision" =~ ^[0-9a-f]{40}$$ ]]; \
	kubectl kustomize deploy/ --load-restrictor LoadRestrictionsNone | \
	  sed -E "s/(runtime-config-[a-z0-9]{10})([^a-z0-9-]|$$)/\1-$${revision:0:12}\2/g; s/__RUNTIME_REVISION__/$$revision/g"

.PHONY: deploy.apply
deploy.apply: # 准备成功后才更新应用
	$(MAKE) --no-print-directory deploy.config | bash scripts/deploy-setup.sh --apply

.PHONY: deploy.status
deploy.status: # 查看当前部署状态
	kubectl get pods,svc,ingress,pvc -n devcontainer

.PHONY: deploy.logs
deploy.logs: # 查看 opencode 容器日志
	kubectl logs -n devcontainer -l app=devcontainer -c opencode -f

.PHONY: deploy.bash
deploy.bash: # 进入集群里的 opencode 容器
	kubectl exec -it -n devcontainer deployment/app -c opencode -- bash -lc 'exec mise exec -- bash'

.PHONY: deploy.multica-status
deploy.multica-status:
	kubectl exec -n devcontainer deployment/app -c multica -- /home/ubuntu/.local/bin/multica daemon status --output json

.PHONY: deploy.multica-logs
deploy.multica-logs:
	kubectl logs -n devcontainer deployment/app -c multica -f
