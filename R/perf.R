#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# Libraries
require(dplyr)

# AUC (see Liu 2011)
computeAUC <- function(pos.scores, neg.scores, n_sample=100000) {
	# Args:
	#   pos.scores: scores of positive observations
	#   neg.scores: scores of negative observations
	#   n_samples : number of samples to approximate AUC
	
	pos.sample <- sample(pos.scores, n_sample, replace=TRUE)
	neg.sample <- sample(neg.scores, n_sample, replace=TRUE)
	AUC <- mean(1.0*(pos.sample > neg.sample) + 0.5*(pos.sample==neg.sample))
	return(AUC)
}

# Accuracy_indices (see Liu 2011 and Pontius 2008)
accuracy_indices <- function(pred, obs) {
  
  if (identical(dim(pred),as.integer(c(2,2)))) {
    df <- pred
    n00 <- df[1,1]
    n10 <- df[2,1]
    n01 <- df[1,2]
    n11 <- df[2,2]
  } else {
    
    # Create data-frame
    df <- data.frame(pred=pred, obs=obs)
    
    # Confusion matrix
    n00 <- sum((df["pred"] == 0) & (df["obs"] == 0))
    n10 <- sum((df["pred"] == 1) & (df["obs"] == 0))
    n01 <- sum((df["pred"] == 0) & (df["obs"] == 1))
    n11 <- sum((df["pred"] == 1) & (df["obs"] == 1))
  }
  
  # Accuracy indices
  N <- n11 + n10 + n00 + n01
  OA <- (n11 + n00) / N
  FOM <- n11 / (n11 + n10 + n01)
  Sensitivity <- n11 / (n11 + n01)
  Specificity <- n00 / (n00 + n10)
  TSS <- Sensitivity + Specificity - 1
  Prob_1and1 <- ((n11 + n10) / N) * ((n11 + n01) / N)
  Prob_0and0 <- ((n00 + n01) / N) * ((n00 + n10) / N)
  Expected_accuracy <- Prob_1and1 + Prob_0and0
  Kappa <- (OA - Expected_accuracy) / (1 - Expected_accuracy)
  
  # Results
  r <- data.frame(OA=round(OA, 2), EA=round(Expected_accuracy, 2),
                  FOM=round(FOM, 2),
                  Sen=round(Sensitivity, 2),
                  Spe=round(Specificity, 2),
                  TSS=round(TSS, 2), K=round(Kappa, 2))
  
  return(r)
}

# Performance
performance_index <- function(data_valid, theta_pred) {
  # Model predictions for validation dataset
  data_valid$theta_pred <- theta_pred
  # Number of observations
  nforest <- sum(data_valid$fordefor==1)  # 1 for forest in fordefor
  ndefor <- sum(data_valid$fordefor==0)
  which_forest <- which(data_valid$fordefor==1)							
  which_defor <- which(data_valid$fordefor==0)
  # Performance at 1%, 10%, 25%, 50% change
  performance <- data.frame(perc=c(1,5,10,25,50),FOM=NA,OA=NA,EA=NA,
                            Spe=NA,Sen=NA,TSS=NA,K=NA,AUC=NA)
  # Loop on prevalence
  for (i in 1:length(performance$perc)) {
    perc <- performance$perc[i]
    ndefor_samp <- min(round(nforest*(perc/100)/(1-perc/100)),ndefor)
    samp_defor <- sample(which_defor,size=ndefor_samp,replace=FALSE)
    data_extract <- data_valid[c(which_forest,samp_defor),]
    data_extract$pred <- 0
    # Probability threshold to transform probability into binary values
    proba_thresh <- quantile(data_extract$theta_pred, 1-perc/100)  # ! must be 1-proba_defor
    data_extract$pred[data_extract$theta_pred > proba_thresh] <- 1
    # Computing accuracy indices
    pred <- data_extract$pred
    obs <- 1-data_extract$fordefor
    perf <- accuracy_indices(pred,obs) %>% 
      dplyr::select(FOM,OA,EA,Spe,Sen,TSS,K)
    performance[i,2:8] <- perf
    # AUC
    pos.scores <- data_extract$theta_pred[data_extract$fordefor==0]
    neg.scores <- data_extract$theta_pred[data_extract$fordefor==1]
    performance$AUC[i] <- round(computeAUC(pos.scores,neg.scores),2)
  }
  return(performance)
}

# npix2ha
npix2ha <- function(npix, res=30) {
	return(npix*(res^2)/10000)
}

# End