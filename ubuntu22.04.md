# docker 
docker build -t cuda-ubuntu24-base:latest .

運行
docker run --gpus all -it --name cuda-dev-container cuda-ubuntu24-base


docker tag cuda-ubuntu24-complete:latest infinirc/cuda-ubuntu24-complete:latest
docker login
docker push infinirc/cuda-ubuntu24-complete:latest

docker tag cuda-ubuntu24-complete:latest registry.infinirc.com/ubuntu-k8s/cuda-ubuntu24-complete:latest

docker push registry.infinirc.com/ubuntu-k8s/cuda-ubuntu24-complete:latest

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cuda-dev-4gb
  namespace: default
spec:
  containers:
  - name: dev-container
    image: infinirc/cuda-ubuntu24-complete:latest
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 4000
        nvidia.com/gpucores: 30
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: "all"
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: "all"
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
EOF
```











---
# 刪除
kubectl delete pod cuda-dev-4gb

# 創建
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cuda-dev-4gb
  namespace: default
spec:
  containers:
  - name: dev-container
    image: nvidia/cuda:12.1.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 4000  # 4GB 顯存
        nvidia.com/gpucores: 30  # 30% 算力
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: "all"
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: "all"
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
EOF

kubectl exec -it cuda-dev-4gb -- bash


apt-get update
apt-get install -y wget curl vim nano git sudo build-essential cmake python3 python3-pip
