apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: __APP_NAME__
  namespace: __ARGOCD_NAMESPACE__
spec:
  project: default
  source:
    repoURL: __REPO_URL__
    targetRevision: __TARGET_REVISION__
    path: __APP_PATH__
  destination:
    server: https://kubernetes.default.svc
    namespace: __DEV_NAMESPACE__
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
