# rm(list=ls())

library(tidyverse)
library(foreign)
library(sf)
library(CoordinateCleaner)

# Written by Ellie Linden in June 2026
# Written using R version 4.6.0

# The purpose of this script is to clean GBIF occurrence points and calculate intersection statistics with protected areas and KBAs.
# See the "1_InputDataPrep" python script for the processing completed to prep some of the input datasets utilized in this code (i.e. protected areas and KBAs).
# At the time of its development, this script includes all 7 big cats within the GBIF dataset.

# Notes for re-running the script and future update considerations:
# - The categories in the "IUCN.red.list.categories.version.2025.2" are currently manually pulled from the IUCN red list website (where this version is then specified in "red.list.version"). The object names/underlying data should be updated as needed to reflect the appropriate versions.
# - The "gbif.download.citation" should be updated to use the download from the "simple" download provided in the email from GBIF.
# - Since tiger was the species of focus for the Big Cat Dashboard prototype, an extra step was completed to identify points that fell in the incorrect continents for removal. In the future, this could be completed for other species and/or the cleaning filters adjusted to account for these.
# - The year 2001 was used as the cut-off to align with the earliest year represented by the Species Conservation Landscapes dataset; if this layer ever became associated with a different dataset containing an earlier timeframe, this could be adjusted.

# Script start time:
script.start.time <- Sys.time()
print(str_c("Script started: ", script.start.time))

######################
### Set Workspaces ###
######################
WS <- "E:/Ellie/BigCats/"

###################
### Import Data ###
###################
gbif.download <- read_tsv(str_c(WS, "Data/GBIF/Felidae_download_20260427/Inputs/Unzipped/occurrences.csv"),
                          na = "", 
                          locale = locale(encoding = "UTF-8"),
                          show_col_types = FALSE) # the extra arguments help retain ISO2 properly (e.g."NA" for Namibia rather than converting to no data) 
ProtectedAreas <- st_read(dsn = str_c(WS,"AnalysisOutputs_2026_June/ProtectedAreas/Merged/ProtectedAreasMerged.gdb"),
                          layer = "ProtectedAreas_all_dissolved2")
KBAs <- st_read(str_c(WS, "AnalysisOutputs_2026_June/KBAs/Intermediate/KBAs_prj_diss_generalized100m.shp"))
Incorrect.Tiger.Points <- read.csv(str_c(WS,"Data/GBIF/Felidae_download_20260427/IncorrectTigerPoints.csv"))
CountryCodes.UNSD <- read.csv(str_c(WS,"Data/CountryCodes/UNSD_CountryCodes.csv")) # needed to join ISO2 codes
CountryCodes.GAUL <- read.dbf(str_c(WS,"Data/CountryCodes/CountryBoundaries/GAUL_2024/Unzipped/GAUL_2024_L1.dbf"))

print("Data imported")

##################################
### Create Objects for Joining ###
##################################

### Create clean country code lookup dataframe ###
Country.Code.Lookup <- CountryCodes.GAUL %>% 
  select(iso3_code, gaul0_name) %>% 
  left_join(CountryCodes.UNSD %>% select(ISO2, ISO3),
            by = c("iso3_code" = "ISO3")) %>% 
  # Manually set cases where ISO2 was missing from UNSD dataset
  mutate(ISO2 = case_match(iso3_code,
                       "NAM" ~ "NA",
                       "HKG" ~ "HK",
                       "MAC" ~ "MO",
                       "BES" ~ "BQ",
                       "TWN" ~ "TW",
                       .default = ISO2)) %>% 
  # Fix cases when ISO3 is duplicated
  group_by(iso3_code) %>% 
  summarise(ISO2 = first(ISO2),
            CountryName = str_c(sort(unique(gaul0_name)), collapse = " / "),
            .groups = "drop") %>% 
  rename(ISO3 = iso3_code)

### Identify 7 Big Cats ###
big.cat.species <- c("Acinonyx jubatus", "Panthera onca", "Panthera pardus", "Panthera leo",
                     "Puma concolor", "Uncia uncia", "Panthera tigris")

### Specify Common Names ###
common.names <- tibble(species    = c("Acinonyx jubatus", "Panthera onca", "Panthera pardus", "Panthera leo",
                 "Puma concolor", "Uncia uncia", "Panthera tigris"),
                 commonName = c("Cheetah", "Jaguar", "Leopard", "Lion", "Puma", "Snow leopard", "Tiger"))

### Specify IUCN Red List Categories (version 2025-2) ###
IUCN.red.list.categories.version.2025.2 <- tibble(species             = c("Acinonyx jubatus", "Panthera onca", "Panthera pardus", "Panthera leo",
                          "Puma concolor", "Uncia uncia", "Panthera tigris"),
                          iucnRedListCategory = c("VU", "NT", "VU", "VU", "LC", "VU", "EN"))

red.list.version <- "2025-1"
gbif.download.citation <- "GBIF.org (25 February 2026) GBIF Occurrence Download https://doi.org/10.15468/dl.zgsjx8"

### Define Mollweide projection ###
mollweide_crs <- "+proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

print("Variables set")

###########################
### Clean & Filter Data ###
###########################

# NOTE: These cleaning steps were adapted from the following blog develoed by GBIF: https://data-blog.gbif.org/post/gbif-filtering-guide/

### Clean Data ###
gbif.clean <- gbif.download %>%
  filter(occurrenceStatus == "PRESENT") %>%
  filter(!basisOfRecord %in% c("FOSSIL_SPECIMEN", "LIVING_SPECIMEN")) %>%
  filter(year >= 2001) %>%
  filter(coordinatePrecision < 0.01 | is.na(coordinatePrecision)) %>%
  filter(coordinateUncertaintyInMeters < 10000 | is.na(coordinateUncertaintyInMeters)) %>%
  filter(!coordinateUncertaintyInMeters %in% c(301, 3036, 999, 9999)) %>%
  filter(!decimalLatitude == 0 | !decimalLongitude == 0) %>%
  cc_cen(buffer = 2000) %>%
  cc_cap(buffer = 2000) %>%
  cc_inst(buffer = 2000) %>%
  cc_sea() %>%
  distinct(decimalLongitude, decimalLatitude, speciesKey, datasetKey, .keep_all = TRUE) %>% 
  # Remove tiger points that fall in Europe, Africa, and North America
  filter(!gbifID %in% c(Incorrect.Tiger.Points$ï..gbifID))

### Filter to 7 Big Cats ###
gbif.clean.big.cats <- gbif.clean %>%
  filter(species %in% big.cat.species)

### Join Fields ###
gbif.clean.big.cats <- gbif.clean.big.cats %>%
  left_join(common.names, by = "species") %>%
  left_join(IUCN.red.list.categories.version.2025.2, by = "species") %>%
  left_join(Country.Code.Lookup, by = c("countryCode" = "ISO2")) %>%
  mutate(gbif_download_citation = gbif.download.citation,
         RedListVersion         = red.list.version)

### Convert to sf — assign WGS84 first, then reproject to Mollweide ###
gbif.clean.big.cats.sf <- gbif.clean.big.cats %>%
  st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), crs = 4326) %>%
  st_transform(crs = mollweide_crs)

print("Data cleaned and filtered")

####################################
### Calculate Summary Statistics ###
####################################

### Named list of dissolved polygon layers (only geometry, no attributes) ###
boundary_layers <- list(KBAs  = KBAs[, attr(KBAs, "sf_column")],
                        ProtectedAreas = ProtectedAreas[, attr(ProtectedAreas, "sf_column")])

### Pre-compute total points per species and country (denominator) ###
species_country_totals <- gbif.clean.big.cats.sf %>%
  st_drop_geometry() %>%
  group_by(species, commonName, iucnRedListCategory, ISO3) %>%
  summarise(n_total = n(), .groups = "drop")

### Pre-allocate results list ###
results_list <- vector("list", length(boundary_layers))

### Loop through boundary layers to calculate statistics ###
for (i in seq_along(boundary_layers)) {
  
  print(str_c("Processing layer ", i, " of ", length(boundary_layers), ": ", names(boundary_layers)[i]))
  
  points_within <- st_join(gbif.clean.big.cats.sf,
                           boundary_layers[[i]],
                           join = st_within,
                           left = FALSE)
  
  print(str_c("Join complete for ", names(boundary_layers)[i], " — summarising..."))
  
  results_list[[i]] <- points_within %>%
    st_drop_geometry() %>%
    group_by(species, commonName, iucnRedListCategory, ISO3) %>%
    summarise(n_within = n(), .groups = "drop") %>%
    left_join(species_country_totals, by = c("species", "commonName", "iucnRedListCategory", "ISO3")) %>%
    mutate(layer = names(boundary_layers)[i],
           pct_within = round((n_within / n_total) * 100, 2)) %>%
    left_join(Country.Code.Lookup %>% select(ISO3, CountryName), by = "ISO3") %>%
    relocate(layer, species, commonName, iucnRedListCategory, ISO3, CountryName, n_total, n_within, pct_within)
}

summary_df <- bind_rows(results_list)

###################
### Export Data ###
###################

# ----------------------------------------------------- #
# --- Export Spatial File (Web Mercator Projection) --- #
# ----------------------------------------------------- #

### Reproject to WGS 1984 Web Mercator for visualizing on web map ###
gbif.clean.big.cats.sf.WebMercator <- st_transform(gbif.clean.big.cats.sf, crs = 3857)
print("SF object projected")

### Export as Spatial File ###
# NOTE: Errors were thrown when attempting to export as a feature class, which is why this exports to a shapefile. This causes many of the output field names to shorten.
st_write(gbif.clean.big.cats.sf.WebMercator, str_c(WS, "AnalysisOutputs_2026_June/GBIF/Felidae_download_20260427/GBIF_Spatial_WebMercator/GBIF_BigCats_20260713.shp"))
print("Spatial file exported")

# -------------------------- #
# --- Summary Statistics --- #
# -------------------------- #

### Export summary statistics table ###
write.table(summary_df, str_c(WS, "AnalysisOutputs_2026_June/GBIF/Felidae_download_20260427/SummaryStats/GBIF_summary_20260713.csv"), row.names = FALSE, col.names = TRUE)
print("Data exported")

# Script end time:
print(str_c("Script ended: ", Sys.time()))
print(str_c("Total runtime: ", round(difftime(Sys.time(), script.start.time, units = "hours"), 2), " hours"))

print("SCRIPT COMPLETE")
