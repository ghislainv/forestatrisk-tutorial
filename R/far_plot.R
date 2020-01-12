#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

require(broom)
require(glue)
require(raster)
require(rasterVis)
require(scales) # for scales::squish()
require(grid) # for grid::unit()
require(sf)
require(dplyr)
require(ggplot2)
require(rgdal)

# Theme
## Setting basic theme options for plot with ggplot2
theme_base <- theme(axis.line=element_blank(),
										axis.text.x=element_blank(),
										axis.text.y=element_blank(),
										axis.ticks=element_blank(),
										axis.title.x=element_blank(),
										axis.title.y=element_blank(),
										legend.position="none",
										plot.margin=grid::unit(c(0,0,0,0),"null"),
										panel.spacing=grid::unit(c(0,0,0,0),"null"),
										plot.background=element_rect(fill="transparent"),
										panel.background=element_rect(fill="transparent"),
										panel.grid.major=element_blank(),
										panel.grid.minor=element_blank(),
										panel.border=element_blank())

# rho_plot()
rho_plot <- function(input_raster, input_vector, output_file, quantiles_legend=c(0.025,0.975), ...) {
	# Rho limits for legend
	rho_quantiles <- quantile(values(input_raster),quantiles_legend,na.rm=TRUE) 
	rho_bound <- max(sqrt(rho_quantiles^2))
	rho_limits <- c(-rho_bound,rho_bound)
	# Call to ggplot
	p <- rasterVis::gplot(input_raster) +
		geom_raster(aes(fill=value)) +
		scale_fill_gradientn(colours=c("forestgreen","yellow","red"),na.value="transparent",
												 limits=rho_limits, oob=scales::squish) +
		geom_polygon(data=broom::tidy(input_vector), aes(x=long, y=lat, group=id), colour="black", fill="transparent", size=0.3) +
		theme_bw() + theme_base + coord_fixed()
	# Save plot
	ggsave(output_file, ...)
	# Return message an plot
	cat(glue("Results plotted to \"{output_file}\"\n"))
	return(p)
}

# diff_plot(). To be done: modify with sf
diff_plot <- function(input_df, input_vector, output_file,
                      ext=NULL, rect=NULL, ...) {
	# Crop raster
	if (!is.null(ext)) {
		input_df <- input_df %>%
		  dplyr::filter(X >= xmin(e), X <= xmax(e),
		                Y >= ymin(e), Y <= ymax(e))
		xlim = c(xmin(e),xmax(e))
		ylim = c(ymin(e),ymax(e))
	} else {
		xlim = NULL
		ylim = NULL
	}
	# Call to ggplot
	p <- ggplot(NULL, aes(X, Y)) +
	    geom_raster(data=input_df, aes(fill=Var)) +
		scale_fill_manual(values=c("red","forestgreen","darkblue","lightblue"),
		                  na.value="transparent", guide="none") +
		{if (!is.null(rect))
			geom_rect(data=rect, inherit.aes=FALSE, aes(xmin=xmin,xmax=xmax,
			                                            ymin=ymin,ymax=ymax,group=id),
								fill="transparent", colour="black", size=0.3)
		} +
		geom_polygon(data=broom::tidy(input_vector), inherit.aes=FALSE, 
		             aes(x=long, y=lat, group=id),
								 colour="black", fill="transparent", size=0.3) +
		theme_bw() + theme_base + coord_fixed(ratio=1, xlim, ylim, expand=FALSE)
	# Save plot
	ggsave(output_file, p, ...)
	# Return message and plot
	cat(glue("Results plotted to \"{output_file}\""))
	return(p)
}

# Function to resample rasters at 1km and return a data.frame
# that can be plot with ggplot2::geom_raster()
resamp2df <- function(input_file,output_file,res=1000) {
  Res <- res
  Input <- input_file
  Output <- output_file
  system(paste0("gdalwarp -overwrite -tap -tr ",Res," ",Res," -r near \\
                -ot Byte -co 'COMPRESS=LZW' -co 'PREDICTOR=2' ",Input," ",Output))
  #gdalUtils::gdalwarp(Input, Output, overwrite=TRUE, tap=TRUE, tr=c(Res,Res),
  #		 r="near", ot="Byte", co=list("COMPRESS=LZW","PREDICTOR=2"),
  #		 verbose=TRUE)
  r <- raster(output_file)
  rdf <- data.frame(rasterToPoints(r))
  colnames(rdf) <- c("X","Y","Var")
  rdf$Var <- factor(rdf$Var)
  return(rdf)
}

# End