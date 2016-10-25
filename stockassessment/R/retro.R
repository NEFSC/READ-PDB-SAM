##' runwithout helper function
##' @param fit a fittes model objest as returned from sam.fit
##' @param year a vector of years to be excluded.  When both fleet and year are supplied they need to be of same length as only the pairs are excluded
##' @param fleet a vector of fleets to be excluded.  When both fleet and year are supplied they need to be of same length as only the pairs are excluded
##' @param ... extra arguments to sam.fit
##' @details ...
##' @export
runwithout <- function(fit, year=NULL, fleet=NULL, ...){
  data <- fit$data
  if(length(year)==0 & length(fleet)==0){
    idx <- 1:nrow(data$obs)
  }
  if(length(year)>0 & length(fleet)==0){
    idx <- which(!data$obs[,"year"]%in%year)
  }
  if(length(fleet)>0 & length(year)==0){
    idx <- which(!data$obs[,"fleet"]%in%fleet)
  }
  if(length(fleet)>0 & length(year)>0){
    if(length(fleet)!=length(year))stop("length of fleet not equal to length of year: When both fleet and year are supplied they need to be of same length as only the pairs are excluded")
    idx<-!apply(apply(cbind(year,fleet),1,function(s)data$obs[,"year"]%in%s[1] & data$obs[,"fleet"]%in%s[2]),1,any) # could this be done simpler???
  }
  data$obs <- data$obs[idx,]
  data$logobs <- data$logobs[idx]
  suf <- sort(unique(data$obs[,"fleet"])) # sort-unique-fleet
  data$noFleets <- length(suf)
  data$fleetTypes <- data$fleetTypes[suf]
  data$sampleTimes <- data$sampleTimes[suf]
  data$years <- min(as.numeric(data$obs[,"year"])):max(as.numeric(data$obs[,"year"]))
  data$noYears <- length(data$years)
  data$idx1 <- sapply(data$years, function(y){idx<-which(as.numeric(data$obs[,"year"])==y);ifelse(length(idx)==0,-1,min(idx))}) 
  data$idx2 <- sapply(data$years, function(y){idx<-which(as.numeric(data$obs[,"year"])==y);ifelse(length(idx)==0,-1,max(idx))})
  data$nobs <- length(data$logobs[idx])
  
  data$propMat <- data$propMat[rownames(data$propMat)%in%data$years, ]
  data$stockMeanWeight <- data$stockMeanWeight[rownames(data$stockMeanWeight)%in%data$years, ]
  data$natMor <- data$natMor[rownames(data$natMor)%in%data$years, ]
  data$propF <- data$propF[rownames(data$propF)%in%data$years, ]
  data$propM <- data$propM[rownames(data$propM)%in%data$years, ]
  # there may be a later issue with the year range of the last four
  data$landFrac <- data$landFrac[rownames(data$landFrac)%in%data$years, ]  
  data$catchMeanWeight <- data$catchMeanWeight[rownames(data$catchMeanWeight)%in%data$years, ]
  data$disMeanWeight <- data$disMeanWeight[rownames(data$disMeanWeight)%in%data$years, ]
  data$landMeanWeight <- data$landMeanWeight[rownames(data$landMeanWeight)%in%data$years, ]
  data$obs[,"fleet"] <- match(data$obs[,"fleet"],suf)

  .reidx <- function(x){
    if(any(x >= (-0.5))){
      xx<-x[x >= (-.5)]
      x[x >= (-.5)] <- match(xx,sort(unique(xx)))-1
    };
    x
  }
                                  
  conf <- fit$conf
  conf$keyLogFsta <- .reidx(conf$keyLogFsta[suf,,drop=FALSE])
  conf$keyLogFpar <- .reidx(conf$keyLogFpar[suf,,drop=FALSE])
  conf$keyQpow <- .reidx(conf$keyQpow[suf,,drop=FALSE])
  conf$keyVarF <- .reidx(conf$keyVarF[suf,,drop=FALSE])
  conf$keyVarObs <- .reidx(conf$keyVarObs[suf,,drop=FALSE])
  yidx <- conf$keyScaledYears%in%data$obs[data$obs[,'fleet']==1,'year']
  conf$noScaledYears[1,1] <- sum(yidx)
  conf$keyScaledYears <- conf$keyScaledYears[,yidx,drop=FALSE]
  conf$keyParScaledYA <- .reidx(conf$keyParScaledYA[yidx,,drop=FALSE])
  par<-defpar(data,conf)
  
  ret <- sam.fit(data,conf,par,...)
  return(ret)
}




##' retro run 
##' @param fit a fittes model objest as returned from sam.fit
##' @param year either 1) a single integer n in which case runs where all fleets are reduced by 1, 2, ..., n are returned, 2) a vector of years in which case runs where years from and later are excluded for all fleets, and 3 a matrix of years were each column is a fleet and each column corresponds to a run where the years and later are excluded.    
##' @param ncores the number of cores to attemp to use
##' @param mc.silent logical to indicate is output is to be suppressed 
##' @param ... extra arguments to sam.fit
##' @details ...
##' @importFrom parallel mclapply detectCores
##' @export
retro <- function(fit, year=NULL, ncores=detectCores(all.tests = FALSE, logical = TRUE), mc.silent=TRUE, ...){
  data <- fit$data
  y <- fit$data$obs[,"year"]
  f <- fit$data$obs[,"fleet"]
  suf <- sort(unique(f))
  maxy <- sapply(suf, function(ff)max(y[f==ff]))
  if(length(year)==1){
    mat <- sapply(suf,function(ff){my<-maxy[ff];my:(my-year+1)})
  }
  if(is.vector(year) & length(year)>1){
    mat <- sapply(suf,function(ff)year)
  }
  if(is.matrix(year)){
    mat <- year
  }

  if(nrow(mat)>length(unique(y)))stop("The number of retro runs exceeds number of years")
  if(ncol(mat)!=length(suf))stop("Number of retro fleets does not match")

  setup <- lapply(1:nrow(mat),function(i)do.call(rbind,lapply(suf,function(ff)cbind(mat[i,ff]:maxy[ff], ff))))
  runs <- mclapply(setup, function(s)runwithout(fit, year=s[,1], fleet=s[,2], ...), mc.cores=ncores, mc.silent=mc.silent)
  attr(runs, "fit") <- fit
  class(runs)<-"samset"
  runs
}