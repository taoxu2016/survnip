# These functions define the Cox regression models.
# They are executed when this package is loaded via `.onLoad()` and modify the
# parsnip package's model environment.

# These functions are tested indirectly when the models are used. Since this
# function is executed on package startup, you can't execute them to test since
# they are already in the parsnip model database. We'll exclude them from
# coverage stats for this reason.

# nocov

make_cox_reg_survival <- function() {
  parsnip::set_new_model("cox_reg")
  parsnip::set_model_mode("cox_reg", "censored regression")

  parsnip::set_model_engine("cox_reg", mode = "censored regression", eng = "survival")
  parsnip::set_dependency("cox_reg", eng = "survival", pkg =  "survival")
  parsnip::set_dependency("cox_reg", eng = "survival", pkg =  "riskRegression")

  set_model_arg(
    model = "cox_reg",
    eng = "glmnet",
    parsnip = "penalty",
    original = "lambda",
    func = list(pkg = "dials", fun = "penalty"),
    has_submodel = TRUE
  )

  set_model_arg(
    model = "cox_reg",
    eng = "glmnet",
    parsnip = "mixture",
    original = "alpha",
    func = list(pkg = "dials", fun = "mixture"),
    has_submodel = FALSE
  )

  parsnip::set_fit(
    model = "cox_reg",
    eng = "survival",
    mode = "censored regression",
    value = list(
      interface = "formula",
      protect = c("formula", "data"),
      func = c(pkg = "survival", fun = "coxph"),
      defaults = list(x = TRUE)
    )
  )

  parsnip::set_encoding(
    model = "cox_reg",
    eng = "survival",
    mode = "censored regression",
    options = list(
      predictor_indicators = "none",
      compute_intercept = FALSE,
      remove_intercept = FALSE,
      allow_sparse_x = FALSE
    )
  )

  parsnip::set_pred(
    model = "cox_reg",
    eng = "survival",
    mode = "censored regression",
    type = "time",
    value = list(
      pre = NULL,
      post = function(x, object) {
        unname(summary(x)$table[, "*rmean"])
      },
      func = c(fun = "survfit"),
      args =
        list(
          formula = quote(object$fit),
          newdata = quote(new_data),
          na.action = stats::na.pass
        )
    )
  )

  parsnip::set_pred(
    model = "cox_reg",
    eng = "survival",
    mode = "censored regression",
    type = "survival",
    value = list(
      pre = NULL,
      post = function(x, object) {
        colnames(x) <- object$spec$method$pred$survival$args$.time
        matrix_to_nested_tibbles_survival(x)
      },
      func = c(pkg = "pec", fun = "predictSurvProb"),
      args =
        list(
          object = quote(object$fit),
          newdata = quote(new_data),
          times = rlang::expr(.time)
        )
    )
  )

  parsnip::set_pred(
    model = "cox_reg",
    eng = "survival",
    mode = "censored regression",
    type = "linear_pred",
    value = list(
      pre = NULL,
      post = NULL,
      func = c(fun = "predict"),
      args =
        list(
          object = quote(object$fit),
          newdata = quote(new_data)
        )
    )
  )
}

make_cox_reg_glmnet <- function() {
  parsnip::set_model_engine("cox_reg", mode = "censored regression", eng = "glmnet")
  parsnip::set_dependency("cox_reg", eng = "glmnet", pkg =  "glmnet")

  parsnip::set_fit(
    model = "cox_reg",
    eng = "glmnet",
    mode = "censored regression",
    value = list(
      interface = "matrix",
      protect = c("x", "y", "weights"),
      func = c(pkg = "survnip", fun = "glmnet_fit_wrapper"),
      defaults = list()
    )
  )

  parsnip::set_encoding(
    model = "cox_reg",
    eng = "glmnet",
    mode = "censored regression",
    options = list(
      predictor_indicators = "traditional",
      compute_intercept = TRUE,
      remove_intercept = TRUE,
      allow_sparse_x = TRUE
    )
  )

  set_model_arg(
    model = "cox_reg",
    eng = "glmnet",
    parsnip = "penalty",
    original = "lambda",
    func = list(pkg = "dials", fun = "penalty"),
    has_submodel = TRUE
  )

  set_model_arg(
    model = "cox_reg",
    eng = "glmnet",
    parsnip = "mixture",
    original = "alpha",
    func = list(pkg = "dials", fun = "mixture"),
    has_submodel = FALSE
  )

  parsnip::set_pred(
    model = "cox_reg",
    eng = "glmnet",
    mode = "censored regression",
    type = "linear_pred",
    value = list(
      pre = NULL,
      post = organize_glmnet_pred,
      func = c(fun = "predict"),
      args =
        list(
          object = expr(object$fit$fit),
          newx = expr(as.matrix(new_data)),
          type = "link",
          s = expr(object$spec$args$penalty)
        )
    )
  )

  parsnip::set_pred(
    model = "cox_reg",
    eng = "glmnet",
    mode = "censored regression",
    type = "survival",
    value = list(
      pre = NULL,
      post = function(x, object) {
        .time <- object$spec$method$pred$survival$args$.time
        res <- calculate_survival_prop(x,
                                       object$fit$time,
                                       object$fit$event,
                                       .time)

        colnames(res) <- .time
        matrix_to_nested_tibbles_survival(res)

      },
      func = c(fun = "predict"),
      args =
        list(
          object = expr(object$fit$fit),
          newx = expr(as.matrix(new_data)),
          type = "link",
          s = expr(object$spec$args$penalty)
        )
    )
  )
}

# nocov end

#' Wrapper for glmnet for survnip
#'
#' Not to be used directly by users
#'
#' @inheritParams glmnet::glmnet
#' @param ... additional parameters passed to glmnet::glmnet.
#' @export
#' @keywords internal
glmnet_fit_wrapper <- function(x, y, alpha = 1, lambda = NULL, ...) {
  fit <- glmnet::glmnet(x, y, family = "cox", alpha = alpha, lambda = lambda)
  res <- list(fit = fit,
              time = y[, 1],
              event = y[, 2],
              times.eval = sort(unique(y[, 1])))
  class(res) <- "coxnet"
  res
}
