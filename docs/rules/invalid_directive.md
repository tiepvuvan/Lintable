# `invalid_directive`

**Invalid directive** · Lintable · default severity: warning

A `// lintable:` comment that isn't a valid directive.

## Rationale

A typo in a directive silently suppresses nothing, so Lintable reports it.
