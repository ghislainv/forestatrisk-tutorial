#####################################
#####################################

######## Setting directory
#setwd("Z:/Ghislain-CIRAD/...")


#=============================================================================#
# Generating data
nobs <- 100
x.seq <- runif(n=nobs,min=0,max=100)
a.target <- 2
b.target <- 2
sigma2.target <- 300
y.seq <- a.target + b.target*x.seq +
         rnorm(n=nobs,mean=0,sd=sqrt(sigma2.target))

# Data-set
Data <- as.data.frame(cbind(y.seq,x.seq))

# Plot
plot(x.seq,y.seq)

#=============================================================================#
# Estimation
M <- lm(y.seq~x.seq,data=Data)
summary(M)
M$coefficients
var(M$residuals)
M$df

#=============================================================================#
# Graphics 

x.pred <- seq(from=0,to=100,length.out=100) # We will predict y for 100 values of x
X.pred <- as.data.frame(x.pred)
names(X.pred) <- "x.seq"
Y.pred <- predict.lm(M,X.pred,interval="confidence",type="response")

pdf(file="Predictions.pdf")
plot(x.seq,y.seq,col=grey(0.7),
     xlab="X",
     ylab="Y",
     main="Simple linear regression") # Row data

# Confidence envelops for predictive posterior
lines(x.pred,Y.pred[,1],col="red",lwd=3)
lines(x.pred,Y.pred[,2],col="blue",lwd=2,lty=2)
lines(x.pred,Y.pred[,3],col="blue",lwd=2,lty=2)
dev.off()

