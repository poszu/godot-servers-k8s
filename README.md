# Godot server in Kubernetes
The repository contains examples for deploying a Godot server on Kubernetes. It contains a Dockerfile to export your Godot project into a .pck file and bundle it into a runnable Docker image together with slim godot server binary. See [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/getting_started/workflow/export/exporting_for_dedicated_servers.html#doc-exporting-for-dedicated-servers) for more information on running Godot dedicated servers for multiplayer.

[Makefile](./Makefile) contains some examples to help you start. It assumes that you have a three server architecture (based on [Godot Multiplayer Tutorial series](https://www.youtube.com/playlist?list=PLZ-54sd-DMAKU8Neo5KsVmq8KtoDkfi4s)):
- Gateway,
- Authenticate,
- Server (Game Server).

It uses [kind](https://kind.sigs.k8s.io) to deploy K8s locally. But you could try with Minikube too.

## Building Docker image
To build a Docker image, You need to create an export preset targetting `Linux/X11`. You can do it from the Godot (`Project/Export.../Add preset`).

```bash
docker build -f ./Dockerfile -t <image tag> --build-arg GODOT_PROJECT_NAME=<Godot project name> <path to Godot project>
```
For example:
```bash
docker build -f ./Dockerfile -t game-server:latest --build-arg GODOT_PROJECT_NAME=Server ./Server
```

## Running a kind cluster
Follow instructions at https://kind.sigs.k8s.io to get kind.

Our cluster will need to expose two node ports so that our `Client` can connect to `Gateway` and `GameServer` services. To make it work with kind, we need to specify these node ports in a cluster configuration yaml. See [kind-cluster-config.yaml](./kind-cluster-config.yaml)

>Note: Godot requires to access ports with both UDP and TCP protocols.

```bash
kind create cluster --config=kind-cluster-config.yaml
```

### Loading our Docker images to the kind cluster
In order to use our local Docker images in kind, they need to be loaded in (see: https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

```bash
kind load docker-image <image tag>
```

## Deploying to Kubernetes
The [deploy.yaml](./deploy.yaml) contains definitions of all resources to run the 3 servers. It exposes `Gateway` on NodePort 30001 and `GameServer` on NodePort 30000. You will need to provide these ports in `Client` (instead of 1909 and 1910 if you followed GDC tutorial).

`Authenticate` is available behind a Service named `auth-server`. To access it from Godot, you need provide `"auth-server"` as the IP of the `Authenticate` server. It exposes ports:
- 1911 for connection with `Gateway`,
- 1912 for connection with `GameServer`.

You will need to provide these addresses in `Gateway` and `GameServer` respectively (instead of "127.0.0.1" if you followed GDC tutorial).

Example of configurations:
```gdscript
# Client/GameServer.gd (script for connection with the game server)
var ip = "127.0.0.1"
#var port := 1909 # when running servers 'locally'
var port := 30000 # when running servers in Kubernetes behind NodePort

# Client/Gateway.gd (script for connection with the gateway server)
var ip = "127.0.0.1"
#var port := 1910 # when running servers 'locally'
var port := 30001 # when running servers in Kubernetes behind NodePort
```

```gdscript
# Server/HubConnection.gd (script for connection with the authorization server)
#var ip := "127.0.0.1" # when running servers 'locally'
var ip := "auth-server" # when running servers in Kubernetes
var port := 1912
```

```gdscript
# Gateway/Authenticate.gd (script for connection with the authorization server)
#var ip := "127.0.0.1" # when running servers 'locally'
var ip := "auth-server" # when running servers in Kubernetes
var port := 1911
```

## One-click deploy with Make
### Prerequisites
#### Code structure
The Makefile assumes you have a following directory structure:
```bash
.
├── Authenticate
├── Dockerfile (from this repo)
├── Gateway
├── kind-cluster-config.yaml (from this repo)
├── Makefile (from this repo)
└── Server
```
#### Dependencies
- export preset configured for every project
- docker installed
- kind installed
- kubectl installed (https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Deploying everything in one command
Run `make deploy`

### Verify Pods and Services
First let's check if K8s Pods are healthy. Run `kubectl get pods`. You should get a similar output.
```
NAME                              READY   STATUS    RESTARTS   AGE
auth-server-7f4579f8d-q7sfj       1/1     Running   0          119s
game-server-5f678f4648-5qc7v      1/1     Running   0          119s
gateway-server-595bd84754-b4zwp   1/1     Running   0          119s
```

To check Services, run `kubectl get svc`. Example healthy output.
```bash
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                               AGE
auth-server      ClusterIP   10.96.54.25     <none>        1911/TCP,1911/UDP,1912/TCP,1912/UDP   2m53s
game-server      NodePort    10.96.242.166   <none>        1909:30000/TCP,1909:30000/UDP         2m53s
gateway-server   NodePort    10.96.19.68     <none>        1910:30001/TCP,1910:30001/UDP         2m53s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP                               3m54s
```

## TODO
- Mounting a persistent volume to Authenticate server in order to store registered users between sessions.
