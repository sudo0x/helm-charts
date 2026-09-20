# VS Code Settings JSON for Helm IntelliSense

This note contains a copy-ready VS Code `settings.json` configuration for Helm and Kubernetes chart development.

It keeps Helm template files colored as YAML while allowing the Helm IntelliSense extension to provide `.Values`, `.Release`, `.Chart`, and helper suggestions.

## Complete settings JSON

Copy the following JSON into your VS Code `settings.json`:

```json
{
  "workbench.iconTheme": "material-icon-theme",
  "editor.formatOnSave": true,
  "editor.insertSpaces": true,
  "editor.tabSize": 2,
  "editor.detectIndentation": false,
  "editor.suggestOnTriggerCharacters": true,
  "editor.quickSuggestions": {
    "other": true,
    "comments": false,
    "strings": true
  },
  "editor.quickSuggestionsDelay": 0,
  "editor.suggest.snippetsPreventQuickSuggestions": false,
  "editor.acceptSuggestionOnEnter": "on",
  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml",
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.formatOnSave": false
  },
  "[markdown]": {
    "editor.wordWrap": "on"
  },
  "files.associations": {
    "Chart.yaml": "yaml",
    "values.yaml": "yaml",
    "*.tpl": "yaml",
    "**/templates/*.yaml": "yaml",
    "**/templates/*.yml": "yaml"
  },
  "yaml.validate": false,
  "yaml.hover": true,
  "yaml.completion": true,
  "helm-intellisense.lintFileOnSave": false,
  "helm-intellisense.customValueFileNames": [
    "values.yaml"
  ],
  "cSpell.words": [
    "nindent",
    "indent",
    "ConfigMap",
    "StatefulSet",
    "ClusterIP",
    "Kubernetes",
    "PostgreSQL",
    "RabbitMQ",
    "Redis",
    "Kafka",
    "Ingress",
    "Helm",
    "KRaft"
  ],
  "editor.fontFamily": "Cascadia Code, Consolas, monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 22,
  "editor.fontLigatures": true,
  "explorer.compactFolders": false,
  "explorer.sortOrder": "type"
}
```

## Why YAML validation is disabled

Helm templates contain Go-template expressions inside YAML:

```yaml
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "sudo0x-postgres.secretName" . }}
{{- end }}
```

The normal YAML validator does not understand the `{{ ... }}` syntax. If YAML validation remains enabled, VS Code may show false errors such as:

```text
Unexpected scalar token
Unexpected flow-map-start token
Block collections are not allowed
```

This setting keeps the YAML colors and completion:

```json
"yaml.validate": false
```

The Helm IntelliSense extension and Helm CLI remain available for chart assistance and validation.

## Why template files stay associated with YAML

The Helm IntelliSense extension supports YAML and registers completion providers for Helm expressions in YAML files. Keeping template files associated with YAML provides syntax colors:

```json
"**/templates/*.yaml": "yaml",
"**/templates/*.yml": "yaml"
```

Do not associate Helm templates with `plaintext`, because that removes syntax coloring and makes the files difficult to read.

## Required extensions

Install these extensions:

```text
redhat.vscode-yaml
tim-koehler.helm-intellisense
ms-kubernetes-tools.vscode-kubernetes-tools
PKief.material-icon-theme
oderwat.indent-rainbow
usernamehw.errorlens
streetsidesoftware.code-spell-checker
```

The most important extensions are:

```text
YAML Language Support
Helm IntelliSense
Kubernetes Tools
```

## Open the complete repository

Open the repository root rather than opening only one template file:

```powershell
code D:\dancypher
```

Helm IntelliSense needs to find the chart structure:

```text
charts/postgres/
├── Chart.yaml
├── values.yaml
└── templates/
    └── secret.yaml
```

Opening only `secret.yaml` may prevent the extension from locating the chart's `values.yaml`.

## Test `.Values` completion

Open:

```text
charts/postgres/templates/secret.yaml
```

Type a temporary expression:

```yaml
test: {{ .Values.
```

Press:

```text
Ctrl+Space
```

Expected suggestions include values defined in `charts/postgres/values.yaml`, such as:

```text
auth
image
persistence
service
resources
```

Test nested values:

```yaml
test: {{ .Values.auth.
```

Expected suggestions may include:

```text
enabled
existingSecret
username
password
usernameKey
passwordKey
```

Remove the temporary test line after checking completion.

## Test other Helm completions

Try these expressions:

```text
{{ .Values.
{{ .Release.
{{ .Chart.
{{ .Capabilities.
{{ include "
```

Use `Ctrl+Space` if suggestions do not open automatically.

Suggestions may not appear after a standalone period outside a Helm expression. Use a complete expression beginning with:

```text
{{ .
```

## Reload VS Code

After saving `settings.json`:

```text
Ctrl+Shift+P
→ Developer: Reload Window
```

Close and reopen the Helm template if necessary.

Check the language indicator in the bottom-right corner. For Helm templates, it should show:

```text
YAML
```

Do not use `Plain Text`, because Plain Text disables YAML colors and completion providers.

## Run Helm IntelliSense commands

With a chart file open, use:

```text
Ctrl+Shift+P
→ Helm-Intellisense: Lint
```

To lint the complete chart:

```text
Ctrl+Shift+P
→ Helm-Intellisense: Lint Chart
```

## Use Helm for authoritative validation

VS Code completion is assistance only. Use Helm to validate the actual chart:

```powershell
helm lint charts\postgres
```

Render the chart:

```powershell
helm template postgres charts\postgres `
  --namespace infrastructure-dev
```

Render with a specific values file:

```powershell
helm template postgres charts\postgres `
  --namespace infrastructure-dev `
  --values charts\postgres\values.yaml
```

Check rendered output for a Secret:

```powershell
helm template postgres charts\postgres `
  --namespace infrastructure-dev `
  | Select-String -Pattern "kind: Secret|name:|stringData:"
```

The final workflow is:

```text
VS Code YAML mode
    Provides colors and editing support.

Helm IntelliSense
    Provides .Values and helper suggestions.

helm lint and helm template
    Provide authoritative chart validation.
```

## Important warning about formatting

Automatic formatting is disabled for YAML in the configuration:

```json
"[yaml]": {
  "editor.formatOnSave": false
}
```

This avoids a formatter rewriting Helm template files unexpectedly. Helm templates contain both YAML and Go-template syntax, so always review changes after formatting or indentation edits.
