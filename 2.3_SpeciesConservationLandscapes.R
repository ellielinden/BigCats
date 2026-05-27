# rm(list=ls())

library(tidyverse)
library(sf)

# Written by Ellie Linden in May 2026
# Written using R version 4.6.0

# The purpose of this script is to process the Wildlife Conservation Society's Species Conservation Landscapes (SCL) dataset and calculate intersection statistics with the protected areas and KBAs.
# See the "1_InputDataPrep" python script for the processing completed to prep some of the input datasets utilized in this code (i.e. protected areas and KBAs).

# Notes for re-running the script and future update considerations:
# - At the time of its development, this script includes SCL for all big cats with data (tiger, lion, jaguar). It is structured to easily incorporate additional cat species if SCL data becomes available.
# - The statistical summaries are developed for donut chart visualizations representing a snapshot for the latest year with data, which at the time of this code development is 2020. In the future, if new data becomes available for later years, this portion of the code may need to be adjusted to reflect the most recent year with data.

# Script start time:
script.start.time <- Sys.time()
print(str_c("Script started: ", script.start.time))

######################################
### Set Main Workspace & Variables ###
######################################
WS <- "E:/Ellie/BIgCats/"
CountryCodes <- read.csv(str_c(WS, "Data/CountryCodes/UNSD_CountryCodes.csv"))
scl_category_order <- read.csv(str_c(WS, "Data/SpeciesConservationLandscapes/scl_category_order.csv"))
ProtectedAreas <- st_read(dsn = str_c(WS,"AnalysisOutputs/ProtectedAreas/Merged/ProtectedAreas_dissolved_merged_Pre2020.gdb"),
                          layer = "ProtectedAreas_Pre2020_dissolved2")
KBAs <- st_read(str_c(WS, "Data/KBAs/2026_03/Processing/KBAs_prj_diss.shp"))

### Clean country codes dataframe ###
Country.ISO3.codes <- CountryCodes %>% 
  select(Country.or.Area, ISO3) %>% 
  rename(CountryName = Country.or.Area)

####################################
### Convert GeoJSONs to Features ###
####################################

# -------------------------------- #
# --- Prep Directories & Lists --- #
# -------------------------------- #

### Set base directory (containing Jaguar, Lion, Tiger folders) ###
scl.inWS <- str_c(WS, "Data/SpeciesConservationLandscapes/version_3_0/Inputs")

### Set the path to the output location (must already exist) ###
scl.outWS <- str_c(WS, "AnalysisOutputs/SpeciesConservationLandscapes/version_3_0/")

### Get all species folders (one level deep, so only the species folders themselves) ###
species_names <- c("Jaguar", "Lion", "Tiger")
species_folders <- file.path(scl.inWS, species_names)

### Define the category types to include (i.e. all except "states") ###
valid_categories <- c("restoration",
                      "restoration_fragment",
                      "species",
                      "species_fragment",
                      "survey",
                      "survey_fragment")

### Build a regex pattern that matches only filenames containing a valid category ###
# e.g. matches "scl_restoration_2001.geojson" but not "scl_states_2001.geojson" (this ensures "scl_states" not included in the output)
valid_pattern <- paste0("scl_(", paste(valid_categories, collapse = "|"), ")_\\d{4}\\.geojson$")

### Define the target projections (mollweide to be used for stats, WGS1984 to be used for displaying spatial data on a web map) ###
crs.mollweide <- "+proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
crs.WGS1984 <- 3857

### Initialize an empty list to store the merged sf object for each species ###
all_species_sf <- list()

print("Variables set")

# -------------------------------------------- #
# --- Loop through species & GeoJSON files --- #
# -------------------------------------------- #
print("Looping through species & geojson files...")

# --- OUTER LOOP: Iterate over each species folder --- #
for (species in species_folders) {
  
  # Extract just the folder name (e.g. "Jaguar") from the full path
  species_name <- basename(species)
  
  # Build the path to the Unzipped folder where the GeoJSONs are stored
  unzipped_path <- file.path(species, "Unzipped")
  
  # Get the full paths of only the GeoJSON files (categories that are not "states")
  geojson_files <- list.files(path       = unzipped_path,
                              pattern    = valid_pattern,
                              full.names = TRUE)
  
  # Initialize an empty list to store each file's sf object for this species
  species_sf_list <- list()
  
  # --- INNER LOOP: Iterate over each valid GeoJSON file for this species --- #
  for (file in geojson_files) {
    
    # Extract the 4-digit year from the filename (e.g. "scl_restoration_2001.geojson" -> "2001")
    year <- str_extract(basename(file), "\\d{4}")
    
    # Construct a datetime of noon on January 1st of the extracted year
    year_datetime <- as.POSIXct(paste0(year, "-01-01 12:00:00"),
                                format = "%Y-%m-%d %H:%M:%S",
                                tz = "UTC")
    
    # Read the GeoJSON into an sf object, join the country code/ category name, then project to mollweide
    sf_object <- st_read(file, quiet = TRUE) %>%
      mutate(species  = species_name,
             datetime = year_datetime) %>%
      left_join(CountryCodes %>% select(ISO2, ISO3), by = c("iso2" = "ISO2")) %>%
      left_join(scl_category_order, by = "ls_key") %>%
      st_transform(crs = crs.mollweide)
    
    # Store this file's sf object in the list, keyed by filename (without extension) to ensure uniqueness across different categories and years
    species_sf_list[[tools::file_path_sans_ext(basename(file))]] <- sf_object
    
  }  # --- end inner loop --- #
  
  # Merge all files for this species into a single sf object and store in the outer list
  all_species_sf[[species_name]] <- bind_rows(species_sf_list)
  
  # Print a progress message for each species once all its files are processed
  cat("Processed:", species_name, "—", length(geojson_files), "files\n")
  
}  # --- end outer loop --- #

# Rename each list element to append "_sf" and assign to global environment
all_species_sf %>%
  setNames(paste0(names(.), "_sf")) %>%
  list2env(envir = .GlobalEnv)

############################
### Calculate Statistics ###
############################

print("Calculating statistics...")

# -------------------------------------- #
# --- Filter species objects to 2020 --- #
# -------------------------------------- #

### Set list for sf objects that represent 2020 ###
all_species_sf_2020 <- list()

### Loop through species to filter to only include files for 2020 ###
for (species_name in names(all_species_sf)) {
  print(species_name)
  all_species_sf_2020[[species_name]] <- all_species_sf[[species_name]] %>% 
    filter(datetime == as.POSIXct("2020-01-01 12:00:00", tz = "UTC"))
}

print("Spatial objects filtered to 2020 for statistics")

# ---------------------------------- #
# --- Check and Repair Geometry  --- #
# ---------------------------------- #

### Set lists for sf objects containing repaired geometry and a log of reasons for invalid geometries ###
all_species_sf_2020_repaired <- list()
validity_log.species <- list()

### Loop through species to repair geometry and document reasons geometry were invalid
for (species_name in names(all_species_sf_2020)) {
  print(species_name)
  
  # Compute validity vectors outside of mutate
  was_invalid    <- !st_is_valid(all_species_sf_2020[[species_name]])
  invalid_reason <- st_is_valid(all_species_sf_2020[[species_name]], reason = TRUE)
  
  # Flag invalid geometries before repair
  validity_log.species[[species_name]] <- all_species_sf_2020[[species_name]] %>%
    st_drop_geometry() %>%
    mutate(species        = species_name,
           was_invalid    = was_invalid,
           invalid_reason = invalid_reason) %>%
    filter(was_invalid)
  
  # Repair geometry
  all_species_sf_2020_repaired[[species_name]] <- all_species_sf_2020[[species_name]] %>%
    st_make_valid()
}

print("Validity computed")

# Combine into a single dataframe
validity_log_df.species <- bind_rows(validity_log.species)

print("Validity dataframes merged")

# ------------------------------------------ #
# --- Calculate Intersection Statistics  --- #
# ------------------------------------------ #

### Set list of the boundary layers ###
boundary_layers <- list(KBAs           = KBAs,
                        ProtectedAreas = ProtectedAreas)

### Set list for the output results
results <- list()

### Loop through boundary layers to calculate statistics with the 2020 SCL files
for (boundary_name in names(boundary_layers)) {
  print(boundary_name)
  
  boundary_geom  <- boundary_layers[[boundary_name]]
  species_results <- list()
  
  for (species_name in names(all_species_sf_2020_repaired)) {
    print(species_name)
    
    species_layer <- all_species_sf_2020_repaired[[species_name]]
    
    # Intersect species layer with dissolved boundary
    intersection <- suppressWarnings(st_intersection(species_layer, boundary_geom)) %>%
      mutate(species            = species_name,
             intersect_area_km2 = as.numeric(st_area(geometry)) / 1e6)
    
    print("Intersection run")
    
    # Summarise by grouping attributes
    species_results[[species_name]] <- intersection %>%
      st_drop_geometry() %>%
      group_by(ISO3, ls_key) %>%
      summarise(intersect_area_km2 = sum(intersect_area_km2, na.rm = TRUE),
                key_order          = first(key_order),
                species            = first(species),
                .groups            = "drop")
    
    print("Intersection summarized")
  }
  
  results[[boundary_name]] <- bind_rows(species_results)
}

print("Intersection analysis complete")

### Extract final outputs into separate dataframes for KBAs and protected areas ### 
results_KBAs           <- results[["KBAs"]]
results_ProtectedAreas <- results[["ProtectedAreas"]]

############################
### Export Stats Results ###
############################

# ---------------------------------------- #
# --- Repair Geometry Validity Outputs --- #
# ---------------------------------------- #

### Set output workspace ###
repair.geometry.validity.outWS <- str_c(WS, "AnalysisOutputs/SpeciesConservationLandscapes/version_3_0/RepairGeometryValidity/")

### Export tables ###
# write.table(validity_log_df.species, str_c(repair.geometry.validity.outWS, "species_RepairGeometry_ValidityLog.csv"), row.names = FALSE, col.names = TRUE)
print("Validity results exported")

# --------------------------- #
# --- Statistical Outputs --- #
# --------------------------- #

### Set output workspace ###
intersection.stats.outWS <- str_c(WS, "AnalysisOutputs/SpeciesConservationLandscapes/version_3_0/IntersectionStats/")

### Export tables ###
# write.table(results_KBAs, str_c(intersection.stats.outWS, "SCL_x_KBAs_20260515.csv"), row.names = FALSE, col.names = TRUE)
# write.table(results_ProtectedAreas, str_c(intersection.stats.outWS, "SCL_x_ProtectedAreas_20260515.csv"), row.names = FALSE, col.names = TRUE)
print("Statistical results exported")

########################################
### Export Features to Spatial Files ###
########################################

print("Exporting spatial features...")

# Loop through spatial objects and export as features to a GeoPackage
for (species_name in names(all_species_sf)) {
  print(species_name)
  all_species_sf[[species_name]] <- all_species_sf[[species_name]] %>%
    # Filter outputs to only include polygon files (in case point files were integrated by accident)
    filter(st_geometry_type(.) %in% c("POLYGON", "MULTIPOLYGON")) %>%
    # Convert all "polygon" features to be "multipolygon" for consistent geometry type
    st_cast("MULTIPOLYGON") %>%
    # Project to WGS 1984 for map visualization
    st_transform(crs = crs.WGS1984) %>%
    st_make_valid()
  st_write(all_species_sf[[species_name]], file.path(scl.outWS, "SCL.gpkg"), layer = species_name, driver = "GPKG")
}

# Script end time:
print(str_c("Script ended: ", Sys.time()))
print(str_c("Total runtime: ", round(difftime(Sys.time(), script.start.time, units = "hours"), 2), " hours"))

print("SCRIPT COMPLETE")