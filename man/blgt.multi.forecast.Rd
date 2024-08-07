% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rexpsmooth.R
\name{blgt.multi.forecast}
\alias{blgt.multi.forecast}
\title{Rlgt LSGT Gibbs run in parallel}
\usage{
blgt.multi.forecast(
  train,
  future,
  n.samples = 20000,
  burnin = 10000,
  parallel = T,
  m = 1,
  homoscedastic = F
)
}
\arguments{
\item{train}{A list of training series.}

\item{future}{A list of corresponding future values of the series.}

\item{n.samples}{The number of samples to sample from the posterior (the default is 2e4).}

\item{burnin}{The number of burn in samples (the default is 1e4).}

\item{parallel}{Whether run in parallel or not (Boolean value only, default \code{TRUE}).}

\item{m}{The seasonality period, with default \code{m=1}, i.e., no seasonality specified.}

\item{homoscedastic}{Run with homoscedastic or heteroscedastic version of the Gibbs sampler version. By default it is set to \code{FALSE}, i.e., run a heteroscedastic model.}
}
\value{
returns a forecast object compatible with the forecast package in R
}
\description{
Fit a list of series and produce forecast, then calculate the accuracy.
}
\examples{
\dontrun{demo(exampleScript)}
\dontrun{
## Build data and test
library(Mcomp)
M3.data <- subset(M3,"yearly")

train.data = list()
future.data = list()
for (i in 1:645)
{
  train.data[[i]] = as.numeric(M3.data[[i]]$x)
  future.data[[i]] = as.numeric(M3.data[[i]]$xx)  
}

## Test -- change below to test more series
w.series = 1:20
# w.series = 1:645        # uncomment to test all series

# use 10,000 posterior samples; change n.samples to 20,000 to test that as well if you want
s = system.time({
  rv=blgt.multi.forecast(train.data[w.series], future.data[w.series], n.samples=1e4)
})

s                         # overall timing info
s[[3]] / length(w.series) # per series time

mean(rv$sMAPE)            # performance in terms of mean sMAPE
mean(rv$InCI)/6           # coverage of prediction intervals -- should be close to 95\%
}
}
