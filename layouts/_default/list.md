# {{ .Title }}

{{ .Content | plainify }}

## Pages

{{ range .Pages }}
- [{{ .Title }}]({{ .Permalink }})
{{ end }}
