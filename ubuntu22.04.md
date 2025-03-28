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
