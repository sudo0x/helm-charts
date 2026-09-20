# VS Code Setup for Helm and Kubernetes

This guide recommends VS Code extensions, fonts, settings, and validation commands for writing Helm charts and Kubernetes manifests more quickly and cleanly.

## Recommended extensions

### YAML Language Support

**Extension ID:** `redhat.vscode-yaml`

Install:

```text
ext install redhat.vscode-yaml
```

Provides:

- YAML syntax highlighting.
- Auto-completion.
- Indentation support.
- YAML validation.
- Schema-based assistance.
- Kubernetes YAML support.

### Kubernetes Tools

**Extension ID:** `ms-kubernetes-tools.vscode-kubernetes-tools`

Install:

```text
ext install ms-kubernetes-tools.vscode-kubernetes-tools
```

Provides:

- Kubernetes Explorer.
- Cluster and context selection.
- Pods, Services, Deployments, Ingress, and Secret browsing.
- Pod log viewing.
- Shell access to Pods.
- Apply and delete actions.
- Kubernetes resource inspection.

### Helm IntelliSense

**Extension ID:** `tim-koehler.helm-intellisense`

Install:

```text
ext install tim-koehler.helm-intellisense
```

Useful for:

```text
templates/deployment.yaml
templates/service.yaml
templates/ingress.yaml
templates/_helpers.tpl
values.yaml
```

It improves:

- Helm template syntax highlighting.
- `.Values` completion.
- Helm function suggestions.
- `_helpers.tpl` readability.
- Go template delimiter visibility.

### Material Icon Theme

**Extension ID:** `PKief.material-icon-theme`

Install:

```text
ext install PKief.material-icon-theme
```

Improves file and folder icons for:

- Helm charts.
- YAML files.
- Kubernetes resources.
- Markdown files.
- Templates.
- Docker files.
- JSON files.

After installation:

```text
Command Palette
→ Preferences: File Icon Theme
→ Material Icon Theme
```

### Indent-Rainbow

**Extension ID:** `oderwat.indent-rainbow`

Install:

```text
ext install oderwat.indent-rainbow
```

YAML depends heavily on indentation. This extension makes indentation levels easier to see and helps prevent incorrectly nested resources.

Example:

```yaml
spec:
  template:
    metadata:
      labels:
```

### Error Lens

**Extension ID:** `usernamehw.errorlens`

Install:

```text
ext install usernamehw.errorlens
```

Displays diagnostics directly beside the affected line, making YAML and configuration errors easier to find.

### Code Spell Checker

**Extension ID:** `streetsidesoftware.code-spell-checker`

Install:

```text
ext install streetsidesoftware.code-spell-checker
```

Useful for:

- README files.
- Helm descriptions.
- YAML comments.
- Documentation.
- Resource names and labels.

## Recommended installation set

Install these first:

```text
redhat.vscode-yaml
ms-kubernetes-tools.vscode-kubernetes-tools
tim-koehler.helm-intellisense
PKief.material-icon-theme
oderwat.indent-rainbow
usernamehw.errorlens
streetsidesoftware.code-spell-checker
```

The three most important extensions for this repository are:

```text
YAML Language Support
Kubernetes Tools
Helm IntelliSense
```

## Recommended programming font

Use one of these fonts:

- Cascadia Code.
- JetBrains Mono.

Recommended default:

```text
Cascadia Code
```

These fonts are clear for:

- YAML indentation.
- Helm template delimiters.
- Kubernetes resource names.
- PowerShell.
- Bash.
- Go template syntax.

If a programming font with strong ligatures is preferred:

```text
JetBrains Mono
```

## VS Code settings

Open the JSON settings editor:

```text
Command Palette
→ Preferences: Open User Settings (JSON)
```

Add or merge these settings:

```json
{
  "editor.formatOnSave": true,
  "editor.insertSpaces": true,
  "editor.tabSize": 2,
  "editor.detectIndentation": false,

  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml",
    "editor.insertSpaces": true,
    "editor.tabSize": 2
  },

  "[markdown]": {
    "editor.wordWrap": "on"
  },

  "files.associations": {
    "*.yaml": "yaml",
    "*.yml": "yaml",
    "Chart.yaml": "yaml",
    "values.yaml": "yaml",
    "*.tpl": "helm"
  },

  "yaml.validate": true,
  "yaml.hover": true,
  "yaml.completion": true,

  "editor.fontFamily": "Cascadia Code, Consolas, monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 22,
  "editor.fontLigatures": true,

  "explorer.compactFolders": false,
  "explorer.sortOrder": "type"
}
```

## Why use two-space indentation?

Two spaces is the common convention for Kubernetes YAML and Helm values:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example
spec:
  replicas: 1
```

Avoid tabs in YAML. Use spaces consistently.

## Helm template files

Helm templates contain Go template syntax inside YAML:

```yaml
metadata:
  name: {{ include "example.fullname" . }}
```

The file is not plain YAML until Helm renders it. This means the YAML extension may show warnings for valid Helm expressions.

Common Helm files include:

```text
Chart.yaml
values.yaml
templates/_helpers.tpl
templates/deployment.yaml
templates/service.yaml
templates/ingress.yaml
```

## Validate Helm with Helm

VS Code suggestions are useful, but Helm itself is the final validator.

Lint a chart:

```powershell
helm lint charts\spring-boot-service
```

Render a chart without installing:

```powershell
helm template test charts\spring-boot-service
```

Render with a namespace:

```powershell
helm template orders-service `
  charts\spring-boot-service `
  --namespace applications-dev
```

Render with Ingress enabled:

```powershell
helm template orders-service `
  charts\spring-boot-service `
  --namespace applications-dev `
  --set ingress.enabled=true `
  --set ingress.hosts[0].host=orders.local
```

Validate the complete rendered output:

```powershell
helm template orders-service `
  charts\spring-boot-service `
  --namespace applications-dev `
  | kubectl apply --dry-run=client -f -
```

## Validate Kubernetes resources

List rendered or installed resources:

```powershell
kubectl get all --namespace applications-dev
```

Check events:

```powershell
kubectl get events `
  --namespace applications-dev `
  --sort-by=.lastTimestamp
```

Inspect a resource:

```powershell
kubectl describe deployment <deployment-name> `
  --namespace applications-dev
```

Show the live YAML:

```powershell
kubectl get deployment <deployment-name> `
  --namespace applications-dev `
  -o yaml
```

## Useful VS Code workflow

### Open the repository

```powershell
code D:\dancypher
```

### Work on a chart

Open one chart directory:

```text
charts/
└── spring-boot-service/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

Review `values.yaml` before editing templates. Values define the supported configuration. Templates convert values into Kubernetes resources.

### Use the integrated terminal

Run from the repository root:

```powershell
helm lint charts\spring-boot-service
helm template test charts\spring-boot-service
kubectl get pods --namespace applications-dev
```

### Keep the Problems panel open

Use:

```text
View
→ Problems
```

This shows YAML, Markdown, spelling, and other diagnostics.

## Recommended chart editing habits

- Keep `Chart.yaml` metadata accurate.
- Document every important value in `values.yaml`.
- Use `_helpers.tpl` for names and labels.
- Keep selectors stable after installation.
- Use two spaces for YAML indentation.
- Quote values when YAML type conversion could be surprising.
- Keep Secrets out of ConfigMaps.
- Use fixed image tags instead of `latest`.
- Make optional features disabled by default.
- Render important configuration variants.
- Run `helm lint` before committing.

## Common Helm editing mistakes

### Incorrect indentation

Incorrect:

```yaml
spec:
replicas: 1
```

Correct:

```yaml
spec:
  replicas: 1
```

### Missing template context

Incorrect:

```yaml
{{ include "example.fullname" }}
```

Correct:

```yaml
{{ include "example.fullname" . }}
```

### Incorrect helper indentation

Recommended:

```yaml
labels:
  {{- include "example.labels" . | nindent 2 }}
```

### Invalid selector relationship

The Deployment selector and Pod labels must match:

```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: example

template:
  metadata:
    labels:
      app.kubernetes.io/name: example
```

### Assuming editor validation is enough

Always run:

```powershell
helm lint charts\example
helm template example charts\example
```

Editor validation cannot fully replace Helm rendering.

## Optional useful extensions

These extensions may also help depending on the project:

- Docker: `ms-azuretools.vscode-docker`
- GitLens: `eamodio.gitlens`
- Prettier: `esbenp.prettier-vscode`
- Markdown All in One: `yzhang.markdown-all-in-one`
- EditorConfig: `EditorConfig.EditorConfig`

Install only extensions that provide value for the repository. Too many overlapping formatters can create conflicting formatting behavior.

## Final recommended setup

Use:

```text
Font:
    Cascadia Code

Indentation:
    2 spaces

Primary extensions:
    redhat.vscode-yaml
    ms-kubernetes-tools.vscode-kubernetes-tools
    tim-koehler.helm-intellisense

Visual extensions:
    PKief.material-icon-theme
    oderwat.indent-rainbow
    usernamehw.errorlens

Documentation:
    streetsidesoftware.code-spell-checker
```

Use VS Code for editing and suggestions, but use Helm and Kubernetes commands for final validation:

```powershell
helm lint charts\<chart-name>
helm template <release-name> charts\<chart-name>
kubectl apply --dry-run=client -f <manifest-file>
```
