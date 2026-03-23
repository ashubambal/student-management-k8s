#!/bin/bash

set -e

NAMESPACE="argocd"
RELEASE_NAME="argocd"

echo "🔹 Adding Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update

echo "🔹 Checking namespace..."
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
  kubectl create namespace $NAMESPACE
else
  echo "Namespace exists ✅"
fi

echo "🔹 Checking Helm release..."

if helm status $RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  STATUS=$(helm status $RELEASE_NAME -n $NAMESPACE | grep STATUS | awk '{print $2}')
  echo "Current Helm status: $STATUS"

  if [[ "$STATUS" == "pending-install" || "$STATUS" == "pending-upgrade" || "$STATUS" == "pending-rollback" ]]; then
    echo "⚠️ Release stuck. Cleaning up..."
    helm uninstall $RELEASE_NAME -n $NAMESPACE
    sleep 10
  fi
else
  echo "No existing Helm release found ✅"
fi

echo "🔹 Installing/Upgrading ArgoCD..."
helm upgrade --install $RELEASE_NAME argo/argo-cd \
  --namespace $NAMESPACE

echo "🔹 Waiting for ArgoCD..."
kubectl rollout status deployment/argocd-server -n $NAMESPACE

echo "🔹 Applying root app..."
kubectl apply -f root-app.yaml

echo "✅ Bootstrap completed!"