#!/usr/bin/bash

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ecology.ghislainv.fr
# GDAL version    :2.1.2 (OGR enabled)
# license         :GPLv3
# ==============================================================================

# Make output directory
mkdir -p data_raw
cd data_raw

# Variables
continent="africa"
country="madagascar"
proj="EPSG:32738"
extent="298440 7155900 1100820 8682420"
tiles_long="45-47" # see http://dwtkns.com/srtm/
tiles_lat="15-18"

# ===========================
# SAPM
# ===========================

# Message
echo "Protected area from Rebioma\n"

# Download from Rebioma
url="http://rebioma.net/index.php/en/useful-links/download/doc_download/56-sapm-shapefile-ver-20-12-2010"
wget -O sapm.zip $url
unzip sapm.zip

# Extract only AP and NAP and reproject
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -s_srs EPSG:4326 -t_srs $proj -where "CLASSE='Aire Protégée'" \
        -lco ENCODING=UTF-8 sapm.shp shp_25005_dd.shp

# Convert to kml
ogr2ogr -f 'KML' sapm.kml sapm.shp 

# Rasterize
gdal_rasterize -te $extent -tap -burn 1 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
               -init 0 \
               -a_nodata 255 \
               -ot Byte -tr 30 30 -l sapm sapm.shp sapm.tif

# ===========================
# Roads and town
# ===========================

# Message
echo "Roads, towns and river from OSM\n"

# Download OSM data for Mada from Geofabrik
url="http://download.geofabrik.de/"$continent"/"$country"-latest.osm.pbf"
wget -O country.osm.pbf $url
osmconvert country.osm.pbf -o=country.o5m

# Main roads
osmfilter country.o5m --keep='highway=motorway or highway=trunk or highway=*ary' > roads.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, highway FROM lines WHERE highway IS NOT NULL' \
        -lco ENCODING=UTF-8 roads.shp roads.osm
# Main towns
osmfilter country.o5m --keep='place=city or place=town or place=village' > towns.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, place FROM points WHERE place IS NOT NULL' \
        -lco ENCODING=UTF-8 towns.shp towns.osm
# Main rivers
osmfilter country.o5m --keep='waterway=river or waterway=canal' > rivers.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, waterway FROM lines WHERE waterway IS NOT NULL' \
        -lco ENCODING=UTF-8 rivers.shp rivers.osm

# Rasterize after reprojection for Mada
# towns
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 towns_UTM.shp towns.shp
gdal_rasterize -te $extent -tap -burn 1 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
        -a_nodata 255 \
        -tr 150 150 -l towns_UTM towns_UTM.shp towns.tif
# roads
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 roads_UTM.shp roads.shp
gdal_rasterize -te $extent -tap -burn 1 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
        -a_nodata 255 \
        -tr 150 150 -l roads_UTM roads_UTM.shp roads.tif
# rivers
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 rivers_UTM.shp rivers.shp
gdal_rasterize -te $extent -tap -burn 1 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
        -a_nodata 255 \
        -tr 150 150 -l rivers_UTM rivers_UTM.shp rivers.tif

# Convert to kml
ogr2ogr -f 'KML' towns.kml towns_UTM.shp
ogr2ogr -f 'KML' roads.kml roads_UTM.shp
ogr2ogr -f 'KML' rivers.kml rivers_UTM.shp

# Compute distances
gdal_proximity.py roads.tif _dist_road.tif \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        -values 1 -ot UInt32 -distunits GEO
gdal_proximity.py towns.tif _dist_town.tif \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        -values 1 -ot UInt32 -distunits GEO
gdal_proximity.py rivers.tif _dist_river.tif \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        -values 1 -ot UInt32 -distunits GEO

# Add nodata
gdal_translate -a_nodata 4294967295 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        _dist_road.tif dist_road.tif
gdal_translate -a_nodata 4294967295 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" \
        -co "BIGTIFF=YES" _dist_town.tif dist_town.tif
gdal_translate -a_nodata 4294967295 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        _dist_river.tif dist_river.tif

# ===========================
# SRTM
# ===========================

# Message
echo "SRTM data from CGIAR-CSI\n"

# Download SRTM data from CSI CGIAR
#else "http://srtm.csi.cgiar.org/SRT-ZIP/SRTM_V41/SRTM_Data_GeoTiff"
url="http://gis-lab.info/data/srtm-tif/srtm_["$tiles_long"]_["$tiles_lat"].zip"
curl -L $url -o 'SRTM_V41_#1_#2.zip'

# Unzip
for z in SRTM_*.zip; do
d=$(basename $z .zip)
mkdir $d && unzip $z -d $d
done

# Build vrt file
gdalbuildvrt srtm.vrt */*.tif

# Merge and reproject
gdalwarp -overwrite -t_srs $proj -te $extent -r bilinear \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        -tr 90 90 srtm.vrt altitude.tif

# Compute slope
gdaldem slope altitude.tif slope_.tif -compute_edges \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES"

# Convert to Int16
gdal_translate -ot Int16 \
        -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "BIGTIFF=YES" \
        slope_.tif slope.tif

# # ===========================
# # Cleaning
# # ===========================

# Message
echo "Cleaning directory\n"

# Create clean data directory
mkdir -p ../data/variables
# Copy files
cp -t ../data/variables dist_*.tif *.kml altitude.tif slope.tif sapm.tif
# Remove raw data directory
cd ..
rm -R data_raw

# End
