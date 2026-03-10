## cilium bootstrap

```bash
helm upgrade --install kube-system-cilium cilium/cilium --values cilium-initial-helm.yaml --namespace kube-system --version 1.18.6
```

## flux-bootstrap

```bash
flux bootstrap github \
  --deploy-token-auth \
  --owner=eeveebot \
  --repository=gitops \
  --branch=main \
  --path=flux
```
