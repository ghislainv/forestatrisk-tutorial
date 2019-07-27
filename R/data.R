#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# =========================================
# Forest
# =========================================

# Libraries
library(dataverse)

# Itinial working directory
wd_init <- getwd()

# Server and doi
Sys.setenv("DATAVERSE_SERVER" = "dataverse.cirad.fr")
(dataset <- get_dataset("doi:10.18167/DVN1/AUBRRC"))

# Retrieve files
f <- paste0("for", c(1990,2000,2010,2017),".tif")
for (i in 1:length(f)) {
	writeBin(get_file(f[i], "doi:10.18167/DVN1/AUBRRC"), paste0("data/forest/",f[i]))
}

# Change working directory
dir.create("data/forest")
setwd("data/forest")

# Execute bash script
system("sh ../../Bash/data_Forest_Mada.sh for1990.tif for2000.tif for2010.tif 2000-2010")
system("sh ../../Bash/data_Forest_Mada.sh for2000.tif for2010.tif for2017.tif 2010-2017")

# Reset working directory
setwd(wd_init)

# =========================================
# Other variables
# =========================================

# Execute bash script
system("sh Bash/data_Variables_Mada.sh")

# =====================================
# Data-sets for modelling deforestation
# =====================================

# On 2000-2010
dir.create("data/models/2000-2010")
f <- paste0("data/forest/2000-2010/", c("dist_edge.tif", "dist_defor.tif", "fordefor.tif"))
file.copy(f, "data/models/2000-2010")
v <- paste0("data/variables/", c("dist_river.tif", "dist_road.tif",
								 "dist_town.tif", "sapm.tif", "altitude.tif",
								 "slope.tif"))
file.copy(v, "data/models/2000-2010")

# On 2010-2017
dir.create("data/models/2010-2017")
f <- paste0("data/forest/2010-2017/", c("dist_edge.tif", "dist_defor.tif", "fordefor.tif"))
file.copy(f, "data/models/2010-2017")
v <- paste0("data/variables/", c("dist_river.tif", "dist_road.tif",
								 "dist_town.tif", "sapm.tif", "altitude.tif",
								 "slope.tif"))
file.copy(v, "data/models/2010-2017")
