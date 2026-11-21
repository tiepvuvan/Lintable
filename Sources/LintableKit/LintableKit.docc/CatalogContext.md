# ``LintableKit/CatalogContext``

Where the catalog being checked lives, and the other catalogs its rule asked for.

## Overview

Lintable creates a context for every catalog it checks. ``relativePath`` is the
catalog's path from the directory of the config file. ``catalog(atPath:)`` returns a
catalog that a rule named in ``CatalogRule/referencedCatalogPaths``, by the same path
string, or `nil` when Lintable couldn't read or parse it. ``isCatalog(atPath:)``
tells whether a path from a rule's options names the catalog being checked,
ignoring `./` components.
