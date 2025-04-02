# 在 RKE2 Ubuntu 上配置 Tesla T4 vGPU 


以下是在 RKE2 Ubuntu 環境中設置 Tesla T4 vGPU 的完整配置過程。此步驟經過實際驗證，可以成功讓您的 Kubernetes 集群使用 vGPU 功能。

## 1. 安裝 NVIDIA Container Toolkit

首先，需要安裝 NVIDIA Container Toolkit 以支持容器中的 GPU 訪問：

```bash
# 移除錯誤的套件庫文件（如果存在）
sudo rm -f /etc/apt/sources.list.d/libnvidia-container.list

# 使用通用 DEB 套件庫
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 更新並安裝
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

## 2. 配置 RKE2 的 Containerd

RKE2 使用自己的 Containerd 實例，需要特別配置：

```bash
# 創建設置文件目錄
sudo mkdir -p /var/lib/rancher/rke2/agent/etc/containerd/
sudo mkdir -p /var/lib/rancher/rke2/agent/etc/containerd/conf.d/

# 創建 Containerd 配置文件
sudo tee /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl > /dev/null <<EOF
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "nvidia"

    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
        privileged_without_host_devices = false
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
          BinaryName = "/usr/bin/nvidia-container-runtime"
EOF

# 創建 NVIDIA 運行時配置
sudo tee /var/lib/rancher/rke2/agent/etc/containerd/conf.d/nvidia.toml > /dev/null <<EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "/usr/bin/nvidia-container-runtime"
EOF

# 重啟 RKE2 服務
sudo systemctl restart rke2-server
```

## 3. 驗證 NVIDIA 驅動和配置

確認 NVIDIA 驅動已正確安裝並工作：

```bash
# 確認 NVIDIA 驅動工作正常
nvidia-smi

# 確認 NVIDIA 容器工具安裝正確
nvidia-container-cli info
```

## 4. 標記 GPU 節點

將 GPU 節點標記為可調度 GPU 工作負載：

```bash
kubectl label nodes $(hostname) gpu=on --overwrite
```

## 5. 安裝 vGPU 調度器

使用 Helm 安裝 vGPU 調度器：

```bash
# 添加 vGPU Helm 套件庫
helm repo add vgpu-charts https://4paradigm.github.io/k8s-vgpu-scheduler
helm repo update

# 創建 vGPU 配置文件
cat > vgpu-values.yaml << EOF
scheduler:
  kubeScheduler:
    imageTag: v1.24.0
  env:
    - name: DISABLE_WEBHOOK
      value: "true"
  tolerations:
  - key: "CriticalAddonsOnly"
    operator: "Exists"
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"

devicePlugin:
  tolerations:
  - key: "CriticalAddonsOnly"
    operator: "Exists"
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"

webhook:
  enabled: false

vgpuDevice:
  gpuMemoryUnit: "Mi"
  memoryOvercommit: 1.0  # 可根據需求調整
  coreOvercommit: 1.0    # 可根據需求調整
EOF

# 安裝 vGPU 調度器
helm install vgpu vgpu-charts/vgpu -f vgpu-values.yaml -n kube-system --timeout 10m
```

## 6. 等待 vGPU Pod 運行

確認 vGPU 調度器和設備插件已正確運行：

```bash
kubectl get pods -n kube-system | grep vgpu
```

等待所有 Pod 顯示為 `Running` 狀態。

## 7. 測試 vGPU 功能

創建使用 vGPU 的測試 Pod：

```bash
cat > t4-vgpu-test.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: t4-vgpu-test
spec:
  containers:
    - name: gpu-container
      image: nvidia/cuda:12.4.0-base-ubuntu22.04
      command: ["bash", "-c", "nvidia-smi && sleep 3600"]
      resources:
        limits:
          nvidia.com/gpu: 1
          nvidia.com/gpumem: 4000  # 4000MB 顯存
          nvidia.com/gpucores: 30  # 30% 的計算能力
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"
EOF

kubectl apply -f t4-vgpu-test.yaml
```

## 8. 驗證 vGPU 工作負載

檢查 Pod 狀態並查看其日誌：

```bash
# 檢查 Pod 狀態
kubectl get pod t4-vgpu-test

# 查看 Pod 日誌，確認 GPU 訪問
kubectl logs t4-vgpu-test

# 進入 Pod 並驗證 GPU 訪問
kubectl exec -it t4-vgpu-test -- bash -c "nvidia-smi"
```

## 9. 創建多個 vGPU 工作負載

測試在同一 GPU 上運行多個工作負載：

```bash
cat > t4-vgpu-test2.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: t4-vgpu-test2
spec:
  containers:
    - name: gpu-container
      image: nvidia/cuda:12.4.0-base-ubuntu22.04
      command: ["bash", "-c", "nvidia-smi && sleep 3600"]
      resources:
        limits:
          nvidia.com/gpu: 1
          nvidia.com/gpumem: 4000  # 4000MB 顯存
          nvidia.com/gpucores: 30  # 30% 的計算能力
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"
EOF

kubectl apply -f t4-vgpu-test2.yaml
```

## 10. 監控 vGPU 使用情況

您可以通過以下方式監控 vGPU 使用情況：

```bash
# 查看所有 GPU Pod
kubectl get pods | grep -i gpu

# 檢查 vGPU 監控指標（預設埠 31992）
curl http://localhost:31992/metrics
```

## 進階配置（按需使用）

如需調整 vGPU 資源分配，可以修改 `vgpu-values.yaml` 並升級 Helm 安裝：

```bash
# 調整 vGPU 配置，例如啟用資源超額訂閱
cat > vgpu-advanced.yaml << EOF
scheduler:
  kubeScheduler:
    imageTag: v1.24.0
  env:
    - name: DISABLE_WEBHOOK
      value: "true"
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

devicePlugin:
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

webhook:
  enabled: false

vgpuDevice:
  gpuMemoryUnit: "Mi"
  # 資源過度使用配置
  memoryOvercommit: 1.5  # 允許 150% 的顯存分配
  coreOvercommit: 2.0    # 允許 200% 的核心分配
EOF

# 更新 vGPU 調度器配置
helm upgrade vgpu vgpu-charts/vgpu -f vgpu-advanced.yaml -n kube-system
```


