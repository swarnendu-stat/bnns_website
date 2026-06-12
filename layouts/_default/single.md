# {{ .Title }}

**Date:** {{ .Date.Format "January 2, 2006" }}
**Link:** {{ .Permalink }}
{{ with .Params.tags }}**Tags:** {{ delimit . ", " }}{{ end }}

{{ .RawContent }}
