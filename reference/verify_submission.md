# Verify a downloaded submission's integrity hash

Checks a JSON file downloaded via
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
against its embedded SHA-256 hash, to detect whether it was edited after
being downloaded (e.g. a wrong answer quietly changed to a right one
before being turned in). This is tamper-*evidence*, not proof of
identity: the hash is computed entirely in the reader's own browser with
no server-held secret, so a technical reader could in principle
reproduce it themselves – this is a deterrent and a check against casual
editing, not real cryptographic security.

## Usage

``` r
verify_submission(path)
```

## Arguments

- path:

  Path to a JSON file downloaded via
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).

## Value

Invisibly, a list with `ok` (logical) and the parsed submission
`content`. Also prints a human-readable summary.

## Examples

``` r
if (FALSE) { # \dontrun{
verify_submission("class-101-2026-01-15T12-00-00-000Z.json")
} # }
```
