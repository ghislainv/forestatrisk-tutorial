#!/usr/bin/bash

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ecology.ghislainv.fr
# GDAL version    :2.1.2 (OGR enabled)
# license         :GPLv3
# ==============================================================================

f0=$1
f1=$2
f2=$3
output_dir=$4

# ============================================
# 1. Compute distance to forest edge at date 1
# ============================================
echo "Distance to forest edge\n"

gdal_proximity.py $f1 dist_edge_.tif \
				  -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
                  -values 255 -ot UInt32 -distunits GEO
gdal_translate -a_nodata 0 \
			   -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
			   dist_edge_.tif dist_edge.tif

# ===================================================
# 2. Compute distance to past deforestation at date 1
# ===================================================
echo "Distance to past deforestation\n"

# Set nodata different from 255
gdal_translate -a_nodata 99 \
			   -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
			   $f0 f0_.tif
gdal_translate -a_nodata 99 \
			   -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
			   $f1 f1_.tif
# Create raster fordefor01.tif  with 1:for1, 0:defor01
gdal_calc.py --overwrite -A f0_.tif -B f1_.tif --outfile=fordefor01_.tif --type=Byte \
             --calc="255-254*(A==1)*(B==1)-255*(A==1)*(B==255)" \
             --co "COMPRESS=LZW" --co "PREDICTOR=2" --co "BIGTIFF=YES" \
             --NoDataValue=255
# Compute distance (with option -use_input_nodata YES, it is much more efficient)
gdal_proximity.py fordefor01_.tif dist_defor_.tif \
			      -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
                  -values 0 -ot UInt32 -distunits GEO -use_input_nodata YES
gdal_calc.py --overwrite -A dist_defor_.tif --outfile=dist_defor.tif --type=UInt32 \
             --calc="A*(A!=65535)" \
             --co "COMPRESS=LZW" --co "PREDICTOR=2" --co "BIGTIFF=YES" \
             --NoDataValue=0

# ========================================================================
# 3. Create raster of observations fordefor.tif with 1:for2, 0:defor12
# ========================================================================
echo "Raster of observations\n"

gdal_translate -a_nodata 99 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
               $f2 f2_.tif
gdal_calc.py --overwrite -A f1_.tif -B f2_.tif --outfile=fordefor.tif --type=Byte \
             --calc="255-254*(A==1)*(B==1)-255*(A==1)*(B==255)" \
             --co "COMPRESS=LZW" --co "PREDICTOR=2" --co "BIGTIFF=YES" \
             --NoDataValue=255

# ===========================
# 4. Cleaning
# ===========================
echo "Cleaning directory\n"

rm ./*_.tif
mkdir -p $output_dir
mv dist_edge.tif dist_defor.tif fordefor.tif ./$output_dir

# End
