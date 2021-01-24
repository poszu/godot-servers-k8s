image-load.%:
	kind load docker-image $*

upload-images: image-load.auth-server\:latest image-load.game-server\:latest image-load.gateway-server\:latest


build-all:
	docker build -f ./Dockerfile -t game-server:latest --build-arg GODOT_PROJECT_NAME=Server Server
	docker build -f ./Dockerfile -t auth-server:latest --build-arg GODOT_PROJECT_NAME=Authenticate Authenticate
	docker build -f ./Dockerfile -t gateway-server:latest --build-arg GODOT_PROJECT_NAME=Gateway Gateway

create-cluster:
	kind create cluster --config=kind-cluster-config.yaml

delete-cluster:
	kind delete cluster

deploy: build-all create-cluster upload-images
	kubectl apply -f deploy.yaml
