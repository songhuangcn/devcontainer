export COMPOSE_PROJECT_NAME = workspace-devcontainer

COMPOSE = docker compose -f docker-compose.yml

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
	$(COMPOSE) up -d app
	$(COMPOSE) restart app

.PHONY: logs
logs:
	$(COMPOSE) logs -f app

.PHONY: restart
restart: stop start

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: bash
bash:
	$(COMPOSE) exec app bash

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
deploy.bash: # 进入集群里运行的 app 容器
	kubectl exec -it -n devcontainer deployment/app -c app -- bash
