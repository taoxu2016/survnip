# This function takes a matrix and turns it into list of nested tibbles
# suitable for predict_survival
matrix_to_nested_tibbles_survival <- function(x) {
  res <- as_tibble(x)
  res <- parsnip::add_rowindex(res)
  res <-  pivot_longer(res, -.row,
                       names_to = ".time",
                       values_to = ".pred_survival")
  group_nest(res, .row, .key = ".pred")$.pred
}