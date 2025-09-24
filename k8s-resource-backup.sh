#!/bin/bash

read -p "Enter backup target directory path: " TARGET_DIR

if [ -z "$TARGET_DIR" ]; then
  echo "No directory given, exiting."
  exit 1
fi

mkdir -p "$TARGET_DIR"

# सभी resource kinds यहां लिखें
kinds=("deployment" "service" "secret" "configmap" "ingress" "namespace" "statefulset" "daemonset" "job" "cronjob" "persistentvolumeclaim" "persistentvolume" "replicaset" "horizontalpodautoscaler" "pod" "role" "rolebinding" "clusterrole" "clusterrolebinding" "serviceaccount" "endpoint" "networkpolicy")

for kind in "${kinds[@]}"
do
  KIND_DIR="$TARGET_DIR/$kind"
  mkdir -p "$KIND_DIR"

  # Namespace-specific resources को अलग देखें
  if [[ "$kind" =~ ^(namespace|persistentvolume|clusterrole|clusterrolebinding)$ ]]; then
    for res in $(kubectl get $kind --no-headers -o custom-columns=:metadata.name 2>/dev/null)
    do
      kubectl get $kind $res -o yaml > "$KIND_DIR/$res.yaml"
      echo "Saved: $KIND_DIR/$res.yaml"
    done
  else
    for ns in $(kubectl get ns --no-headers -o custom-columns=:metadata.name)
    do
      for res in $(kubectl get $kind -n $ns --no-headers -o custom-columns=:metadata.name 2>/dev/null)
      do
        kubectl get $kind $res -n $ns -o yaml > "$KIND_DIR/${ns}_${res}.yaml"
        echo "Saved: $KIND_DIR/${ns}_${res}.yaml"
      done
    done
  fi
done
