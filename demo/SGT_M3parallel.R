# Test SGT - M3 monthly data
# This is a most computationally demanding subset of M3, so also a good opportunity to showcase parallel execution
# We will use all cores on the server - the more of them the faster the whole process will be.
# While we are looping through all of the 1428 series, you can see the progress by opening (and refreshing) M3Monthly.html in SGT_M3 subdirectory of your working directory.
# After a few days (on a 6-core computer) you will see something like this:
# Num of cases:1428, sMAPE:13.53, % of time 95p exceeded:6.26, % of time 5p exceeded:5.155, q5Loss:3.913, q95Loss:6.645, q99Loss:2.125"

library(Mcomp)
library(Rlgt)
library(doParallel)
#set.seed(12)
options(width=180)
imageWidth=1000; imageHeight=400


OUTPUT_DIR="SGT_M3"
fullOutputDir=file.path(tempdir(),OUTPUT_DIR)
print(paste("The output will go to",fullOutputDir))
if (!file.exists(fullOutputDir)){
	dir.create(fullOutputDir)
}
htmlFilePath=file.path(fullOutputDir,"M3Monthly.html")
unlink(htmlFilePath)
imagesDir=file.path(fullOutputDir,'images')
if (!file.exists(imagesDir)){
	dir.create(imagesDir)
}
cat(paste0("<html><head><title>",OUTPUT_DIR, "</title></head> <body bgcolor=#D0D0D0>"), file = htmlFilePath, append = FALSE)


numOfCores=parallel:::detectCores()
CLUSTER_SIZE=as.integer(numOfCores/4)  #Each cluster will use 4 cores (as per default in rlgt.control())

M3.data <- subset(M3,"monthly")
SEASONALITY=12
#M3.data <- sample(M3.data) #shuffle
NUM_OF_CASES=length(M3.data)
#NUM_OF_CASES=20
H=length(M3.data[[1]]$xx)

quantileLoss<-function(forec, actual, tau) {
	diff=actual-forec
	pinBallL=pmax(diff*tau,diff*(tau-1))
	mean(pinBallL/actual)*200
}

legend_str_vect=NULL; legend_cols_vect=NULL; legend_char_vect=NULL
legend_str_vect=c(legend_str_vect,"forecast")  
legend_cols_vect=c(legend_cols_vect, 'blue')
legend_char_vect=c(legend_char_vect,'-')

legend_str_vect=c(legend_str_vect,"actuals")  #used for short displays
legend_cols_vect=c(legend_cols_vect, 'black')
legend_char_vect=c(legend_char_vect,'-')

#stopCluster(cl) # this is useful if rerunning the script in the same session. First time it will report error - it is OK
#Sys.sleep(2)
cl = makeCluster(CLUSTER_SIZE, outfile="rclust.out")
registerDoParallel(cl)
sink(); graphics.off();
stanOutputPath='stanOutput.txt' #in working directory
unlink(stanOutputPath)

i=1
ret_df=foreach(i=1:NUM_OF_CASES, .combine=rbind, .inorder=FALSE, .packages=c("Rlgt")) %dopar% { # the long loop :-)	
	if (i==1) { #needs to be done inside every new slave process
		sink(file=stanOutputPath, append=TRUE, split=TRUE)
	}
	series=M3.data[[i]]$sn
	trainData <- M3.data[[i]]$x
	actuals <- M3.data[[i]]$xx
	rstanmodel <- rlgt(trainData, seasonality.type="generalized",
		control=rlgt.control(NUM_OF_ITER=5000), #we do not need to specify seasonality, as it is extracted from M3.data[[i]]$x
		verbose=FALSE)
	forec= forecast(rstanmodel, h = H, level=c(90,98))
	#str(forec$model$params, max.level=1)
	
	imageFileName=paste(series,'.png',sep='')
	relPath=file.path('images',imageFileName)
	filePath=file.path(imagesDir, imageFileName)
	unlink(filePath)
	png(file=filePath, bg="white", width = imageWidth, height = imageHeight, pointsize=16)
	
	plot(forec, main=series)
	if (inherits(trainData,"ts")) {
		lines(actuals, col=1, lwd=2)	
	} else {
		xs=seq(from=length(trainData)+1,to=length(trainData)+ length(actuals))
		lines(xs,actuals, col=1, type='b',lwd=2)	
	}
	legend("topleft", legend_str_vect,
			pch=legend_char_vect, 
			col=legend_cols_vect, cex=1)
	
	dev.off() ;
	cat(paste0('<img src="',relPath,'" alt="',series,'" height="',imageHeight,'" width="',imageWidth,'">'), file = htmlFilePath, append = TRUE)

	sMAPE=mean(abs(forec$mean-actuals)/(forec$mean+actuals))*200
	q95Loss=quantileLoss(forec$upper[,1], actuals, 0.95)	
	q99Loss=quantileLoss(forec$upper[,2], actuals, 0.99)
	q5Loss=quantileLoss(forec$lower[,1], actuals, 0.05)
	cat(paste0("<p> ",Sys.time(), " ",series,  " sMAPE=",signif(sMAPE,3),"% </p>"), file = htmlFilePath, append = TRUE)
	params_txt=NULL;ipar=3
	for (ipar in 3:length(forec$model$params)) {
		paramName=names(forec$model$params)[ipar]
		if (!is.null(params_txt)) params_txt=paste0(params_txt,", ")
		params_txt=paste0(params_txt, paramName, ":",signif(median(forec$model$params[[paramName]]),2))
	}
	cat(paste0("<p> ",params_txt,"</p>"), file = htmlFilePath, append = TRUE)
	
	data.frame(series=series, sMAPE=sMAPE, 
		q5Loss=q5Loss, q95Loss=q95Loss, q99Loss=q99Loss,
		numOfCases95pExceeded=sum(actuals>forec$upper[,1]),
		numOfCases5pExceeded=sum(actuals<forec$lower[,1]))
}	
sMAPE=mean(ret_df$sMAPE)
q95Loss=mean(ret_df$q95Loss)
q99Loss=mean(ret_df$q99Loss)
q5Loss=mean(ret_df$q5Loss)
exceed95=mean(ret_df$numOfCases95pExceeded)/H*100
exceed5=mean(ret_df$numOfCases5pExceeded)/H*100
print(paste0("SUMMARY: Num of cases:", NUM_OF_CASES, ", sMAPE:",signif(sMAPE,4),
  ', % of time 95p exceeded:',signif(exceed95,4), ', % of time 5p exceeded:',signif(exceed5,4), 
	', q5Loss:',signif(q5Loss,4),', q95Loss:',signif(q95Loss,4),', q99Loss:',signif(q99Loss,4) ))
