# Collect student identifying information

Adds a small, ungraded form for the reader to fill in identifying
information before starting a tutorial: name and email required, an ID
optional, by default. Unlike
[`question()`](https://ppbds.github.io/learnr2/reference/question.md),
nothing here is graded and there is no model answer to reveal.

## Usage

``` r
student_info(
  fields = c(name = "Name:", email = "Email:", id =
    "ID (if requested by your instructor):"),
  required = intersect(c("name", "email"), names(fields)),
  id = "student-info",
  submit_button = "Submit",
  edit_button = "Edit"
)
```

## Arguments

- fields:

  A named character vector of field key/label pairs to collect. Defaults
  to name, email, and an optional ID, matching 'tutorial.helpers”s
  `info_section.Rmd`. A field named `"email"` is additionally checked
  for an `"@"` character, regardless of whether it is `required`.

- required:

  Character vector of keys (from `fields`) the reader must fill in.
  Defaults to whichever of `"name"` and `"email"` are actually present
  in `fields`, so ID is optional by default and supplying custom
  `fields` does not require also supplying `required`. A required field
  left blank, or an `"email"` field missing an `"@"`, is flagged inline
  (on blur, and again when the button is clicked) and the form can't be
  submitted until it's fixed. Passing a key that is not in `fields` is
  an error.

- id:

  Stable identifier used to key the saved values in `localStorage`.
  Defaults to `"student-info"`; change it if a single tutorial embeds
  more than one `student_info()` form.

- submit_button:

  Button label while the form is open for editing.

- edit_button:

  Button label while the form is locked on a submission. Clicking it
  reopens the form.

## Value

A `learnr2_info` object, printed as an interactive HTML form.

## Details

The form has two states. While *editing*, the fields are open and the
button reads "Submit". A valid Submit saves the entry, locks the fields,
and switches the button to "Edit". Clicking Edit only reopens the fields
and switches the button back to "Submit", with a note that the change
isn't saved until the next Submit. So the button always tells the reader
whether what they see is what was received. Typing is kept as a draft in
the browser's `localStorage`, so a reload mid-edit loses nothing, but a
draft is never the answer:
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
reports only the last submitted entry, and is blocked until the form is
submitted. A `"reflection_editable"`
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
works the same way. Pair with
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
so a reader can turn their work in.

## Examples

``` r
student_info()
#> <div class="learnr2-info" data-learnr2-info="eyJpZCI6ImxlYXJucjItaW5mby1zdHVkZW50LWluZm8iLCJmaWVsZHMiOlt7ImtleSI6Im5h&#10;bWUiLCJsYWJlbCI6Ik5hbWU6IiwicmVxdWlyZWQiOnRydWV9LHsia2V5IjoiZW1haWwiLCJs&#10;YWJlbCI6IkVtYWlsOiIsInJlcXVpcmVkIjp0cnVlfSx7ImtleSI6ImlkIiwibGFiZWwiOiJJ&#10;RCAoaWYgcmVxdWVzdGVkIGJ5IHlvdXIgaW5zdHJ1Y3Rvcik6IiwicmVxdWlyZWQiOmZhbHNl&#10;fV0sInN1Ym1pdExhYmVsIjoiU3VibWl0IiwiZWRpdExhYmVsIjoiRWRpdCJ9">
#>   <noscript>This form requires JavaScript.</noscript>
#> </div>
student_info(fields = c(name = "Full name:", section = "Section:"), required = "name")
#> <div class="learnr2-info" data-learnr2-info="eyJpZCI6ImxlYXJucjItaW5mby1zdHVkZW50LWluZm8iLCJmaWVsZHMiOlt7ImtleSI6Im5h&#10;bWUiLCJsYWJlbCI6IkZ1bGwgbmFtZToiLCJyZXF1aXJlZCI6dHJ1ZX0seyJrZXkiOiJzZWN0&#10;aW9uIiwibGFiZWwiOiJTZWN0aW9uOiIsInJlcXVpcmVkIjpmYWxzZX1dLCJzdWJtaXRMYWJl&#10;bCI6IlN1Ym1pdCIsImVkaXRMYWJlbCI6IkVkaXQifQ==">
#>   <noscript>This form requires JavaScript.</noscript>
#> </div>
```
