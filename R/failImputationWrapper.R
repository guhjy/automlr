
#' @title Create an mlr learner that catches errors and replaces them with the
#' result of the simplest possible learner.
#'
#' @description
#' When a learner throws an error, its performance is treated by mlr as a
#' "missing value". This behaviour is not always optimal, especially for tuning
#' purposes, since a learner that sometimes fails but otherwise gives good
#' results could still be better than a learner that never fails but gives
#' awful results.
#' 
#' @param learner [\code{Learner}]\cr
#'   The learner to be wrapped.
#' 
#' @return [\code{FailImputationWrapper}]
#' A \code{Learner} that catches errors and returns a dummy model if an error
#' occurs.
makeFailImputationWrapper = function(learner) {
  constructor = switch(learner$type,
      classif = makeRLearnerClassif,
      regr = makeRLearnerRegr,
      surv = makeRLearnerSurv,
      multilabel = makeRLearnerMultilabel,
      stopf("Learner type '%s' not supported.", taskdesc$type))
  wrapper = constructor(
      cl = "FailImputationWrapper",
      short.name = "fiw",
      name = "FailImputationWrapper",
      properties = getLearnerProperties(learner),
      par.set = makeAllTrainPars(getParamSet(learner)),
      par.vals = getHyperPars(learner),
      package = "automlr")
  wrapper$fix.factors.prediction = learner$fix.factors.prediction
  wrapper$learner = removeHyperPars(learner, names(getHyperPars(learner)))
  wrapper
}

trainLearner.FailImputationWrapper = function(.learner, .task, .subset,
    .weights = NULL, ...) {
  learner = setHyperPars(.learner$learner, par.vals = list(...))
  trivialTask = dropFeatures(.task, getTaskFeatureNames(.task))
  trivialModel = train(learner, task = trivialTask, subset = .subset,
      weights = .weights)
  model = try(train(learner, task = .task, subset = .subset,
          weights = .weights), silent = TRUE)
  if (is.error(model) || isFailureModel(model)) {
    model = NULL
  }
  result = list(model = model, trivialModel = trivialModel)
}

predictLearner.FailImputationWrapper = function(.learner, .model, .newdata,
    ...) {
  result = NULL
  if (!is.null(.model$learner.model$model)) {
    result = try(getPredictionResponse(
            predict(.model$learner.model$model, newdata = .newdata)),
        silent = TRUE)
    if (is.error(result) || all(is.na(result))) {
      result = NULL
    }
  }
  if (is.null(result)) {
    getPredictionResponse(predict(.model$learner.model$trivialModel,
            newdata = .newdata))
  } else {
    result
  }
}

getSearchspace.FailImputationWrapper = function(learner) {
  getSearchspace(learner$learner)
}