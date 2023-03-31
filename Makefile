#!/usr/bin/env make

.PHONY: run_website install_kind install_kubectl create_kind_cluster \
	create_docker_registry connect_registry_to_kind_network \
	connect_registry_to_kind create_kind_cluster_with_registry delete_kind_cluster generate_k8s_deployment \
	generate_k8s_ingress


run_website:
	docker build -t 127.0.0.1:5000/explorecalifornia.com . && \
		docker run -p 5000:80 -d --name explorecalifornia.com --rm 127.0.0.1:5000/explorecalifornia.com

install_kubectl:
	brew install kubectl || true;

install_kind:
	curl -o ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.11.1/kind-darwin-arm64

connect_registry_to_kind_network:
	docker network connect kind local-registry || true;

connect_registry_to_kind: connect_registry_to_kind_network
	kubectl apply -f ./kind_configmap.yaml;

create_docker_registry:
	if ! docker ps | grep -q 'local-registry'; \
	then docker run -d -p 5000:5000 --name local-registry --restart=always registry:2; \
	else echo "---> local-registry is already running. There's nothing to do here."; \
	fi

create_kind_cluster: install_kind install_kubectl create_docker_registry
	kind create cluster --image=kindest/node:v1.21.12 --name explorecalifornia.com --config ./kind_config.yaml || true
	kubectl get nodes

create_kind_cluster_with_registry:
	$(MAKE) create_kind_cluster && $(MAKE) connect_registry_to_kind

delete_local_registry:
	docker stop local-registry && docker rm local-registry

delete_kind_cluster:
	$(MAKE) delete_local_registry && kind delete cluster --name explorecalifornia.com

generate_k8s_deployment:
	$(MAKE) create_kind_cluster_with_registry && \
	docker build -t 127.0.0.1:5000/explorecalifornia.com . && \
	docker push 127.0.0.1:5000/explorecalifornia.com && \
	kubectl create deployment --dry-run=client --image localhost:5000/explorecalifornia.com explorecalifornia.com --output=yaml > deployment.yaml && \
	kubectl apply -f deployment.yaml && \
	kubectl get pods -l app=explorecalifornia.com

generate_k8s_service:
	kubectl create service clusterip explorecalifornia-svc --dry-run=client --tcp 80:80 --output=yaml > service.yaml && \
	kubectl apply -f service.yaml

generate_k8s_ingress:
	kubectl create ingress explorecalifornia.com --rule="explorecalifornia.com/*=explorecalifornia-svc:80" --dry-run=client --output=yaml > ingress.yaml && \
	kubectl apply -f ingress.yaml

generate_nginx_ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

deploy_website:
	$(MAKE) generate_k8s_deployment && \
	$(MAKE) generate_k8s_service && \
	$(MAKE) generate_nginx_ingress && \
	$(MAKE) generate_k8s_ingress

show_helm_chart:
	helm show all ./chart

generate_helm_chart:
	helm template ./chart

delete_website:
	kubectl delete all -l app=explorecalifornia.com

install_app:
	helm upgrade --atomic --install -i explore-california-website ./chart
	helm install explore-california-website ./chart
	

