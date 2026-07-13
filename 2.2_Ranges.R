# rm(list=ls())

library(tidyverse)
library(sf)
library(foreign)

# Written by Ellie Linden in June 2026
# Written using R version 4.6.0

# The purpose of this script is to calculate intersection statistics between tiger ranges with the protected areas and KBAs.
# See the "1_InputDataPrep" python script for the processing completed to prep some of the input datasets utilized in this code (i.e. protected areas and KBAs).
# At the time of its development, this script only includes range data for tigers (split into "extant" and "full" range polygons) as provided by IBCA. The code may need to be adjusted in the future to easily incorporate additional cat species and/or account for different input data formatting if that evolves.

# Script start time:
script.start.time <- Sys.time()
print(str_c("Script started: ", script.start.time))

###########################
### Import & Clean Data ###
###########################

### General workspaces ###
WS          <- "E:/Ellie/BigCats/"
outWS.Stats <- str_c(WS, "AnalysisOutputs_2026_June/Ranges/Version_emailed_on_20260421/Outputs/")

### Path to the geodatabase containing country boundary feature classes ###
country_gdb <- str_c(WS, "AnalysisOutputs_2026_June/CountryBoundarySplitting/BoundariesSplit.gdb")

### Path to the geodatabase containing KBA feature classes (named "KBA_{ISO3}") ###
kba_gdb <- str_c(WS, "AnalysisOutputs_2026_June/CountryBoundarySplitting/KBAs_clipped.gdb")

### Path to the geodatabase containing Protected Area feature classes (named "PA_diss_{ISO3}") ###
pa_gdb <- str_c(WS, "AnalysisOutputs_2026_June/CountryBoundarySplitting/ProtectedAreas_clipped_dissolved_all.gdb")

### Import tiger range features ###
tiger_extant <- st_read(str_c(WS, "AnalysisOutputs_2026_June/Ranges/Version_emailed_on_20260421/Intermediate/panthera_tigris_extant_prj.shp"))
tiger_full   <- st_read(str_c(WS, "AnalysisOutputs_2026_June/Ranges/Version_emailed_on_20260421/Intermediate/panthera_tigris_full_prj.shp"))

### Import & Clean Country Codes ###
CountryCodes.GAUL <- read.dbf(str_c(WS,"Data/CountryCodes/CountryBoundaries/GAUL_2024/Unzipped/GAUL_2024_L1.dbf"))
Country.Code.Lookup <- CountryCodes.GAUL %>% 
  select(iso3_code, gaul0_name) %>% 
  # Fix cases when ISO3 is duplicated
  group_by(iso3_code) %>% 
  summarise(CountryName = str_c(sort(unique(gaul0_name)), collapse = " / "),
            .groups = "drop") %>% 
  rename(ISO3 = iso3_code)

print("Variables set")

################################################################################
### STEP 1: Create list of available ISO3 codes from the country geodatabase ###
################################################################################

all_country_layers <- st_layers(country_gdb)$name

iso3_list <- all_country_layers[grepl("^[A-Z]{3}_?$", all_country_layers)]

cat("Found", length(iso3_list), "countries to process:\n")
cat(paste(iso3_list, collapse = ", "), "\n\n")

##############################################
### STEP 2: Initialize single output table ###
##############################################

results <- tibble(iso3 = character(),
                  range_type = character(),
                  boundary_type = character(),
                  area_km2 = numeric(),
                  percentage = numeric())

############################################################
### STEP 3: Main loop — iterate over country boundaries  ###
############################################################

for (iso3 in iso3_list) {
  
  # ---------------------------------------------------------------------------
  # 3a. Load country boundary from geodatabase
  # ---------------------------------------------------------------------------
  
  country_sf <- tryCatch({
    tmp <- st_read(country_gdb, layer = iso3, quiet = TRUE)
    tmp <- st_make_valid(tmp)
    tmp
  },
  error = function(e) {
    cat("  ERROR reading boundary for", iso3, "—", conditionMessage(e), "\n")
    NULL
  }
  )
  
  if (is.null(country_sf)) next
  
  cat("Processing:", iso3, "\n")
  
  # ---------------------------------------------------------------------------
  # 3b. Calculate full country area — used as reference row
  # ---------------------------------------------------------------------------
  
  country_area_km2 <- as.numeric(st_area(st_union(country_sf))) / 1e6
  
  for (boundary_label in c("KBA", "protected_area", "total")) {
    results <- results |>
      add_row(iso3          = iso3,
              range_type    = "full_country",
              boundary_type = boundary_label,
              area_km2      = country_area_km2,
              percentage    = NA_real_)
  }
  
  # ---------------------------------------------------------------------------
  # 3c. Clip tiger ranges to country boundary
  # ---------------------------------------------------------------------------
  
  tiger_extant_clip <- tryCatch(
    st_intersection(tiger_extant, st_union(country_sf)),
    error = function(e) NULL
  )
  
  tiger_full_clip <- tryCatch(
    st_intersection(tiger_full, st_union(country_sf)),
    error = function(e) NULL
  )
  
  # ---------------------------------------------------------------------------
  # 3d. Load KBA layer for this country from kba_gdb
  # ---------------------------------------------------------------------------
  
  kba_clip <- tryCatch({
    tmp <- st_read(kba_gdb, layer = str_c("KBA_", iso3), quiet = TRUE)
    tmp <- st_make_valid(tmp)
    tmp
  },
  error = function(e) NULL
  )
  
  # ---------------------------------------------------------------------------
  # 3e. Load Protected Area layer for this country from pa_gdb
  # ---------------------------------------------------------------------------
  
  pa_clip <- tryCatch({
    tmp <- st_read(pa_gdb, layer = str_c("PA_diss_", iso3), quiet = TRUE)
    tmp <- st_make_valid(tmp)
    tmp
  },
  error = function(e) NULL
  )
  
  # ---------------------------------------------------------------------------
  # 3f. KBA intersection analysis (extant_range and full_range)
  # ---------------------------------------------------------------------------
  
  if (!is.null(kba_clip) && nrow(kba_clip) > 0) {
    
    kba_union <- st_union(kba_clip)
    
    for (tiger_type in c("extant", "full")) {
      
      tiger_geom   <- if (tiger_type == "extant") tiger_extant_clip else tiger_full_clip
      extent_label <- if (tiger_type == "extant") "extant_range" else "full_range"
      
      intersection <- tryCatch(
        st_intersection(tiger_geom, kba_union),
        error = function(e) NULL
      )
      
      if (is.null(intersection) ||
          length(intersection) == 0 ||
          all(is.na(st_geometry(intersection))) ||
          all(st_is_empty(intersection))) {
        
        area_km2 <- 0
        
      } else {
        
        intersection <- intersection[!is.na(st_geometry(intersection)), ]
        intersection <- intersection[!st_is_empty(intersection), ]
        area_km2     <- as.numeric(sum(st_area(intersection)) / 1e6)
        
      }
      
      results <- results |>
        add_row(
          iso3          = iso3,
          range_type    = extent_label,
          boundary_type = "KBA",
          area_km2      = area_km2,
          percentage    = NA_real_
        )
    }
    
  } else {
    
    for (extent_label in c("extant_range", "full_range")) {
      results <- results |>
        add_row(
          iso3          = iso3,
          range_type    = extent_label,
          boundary_type = "KBA",
          area_km2      = 0,
          percentage    = NA_real_
        )
    }
  }
  
  # ---------------------------------------------------------------------------
  # 3g. Protected Area intersection analysis (extant_range and full_range)
  # ---------------------------------------------------------------------------
  
  if (!is.null(pa_clip) && nrow(pa_clip) > 0) {
    
    pa_union <- st_union(pa_clip)
    
    for (tiger_type in c("extant", "full")) {
      
      tiger_geom   <- if (tiger_type == "extant") tiger_extant_clip else tiger_full_clip
      extent_label <- if (tiger_type == "extant") "extant_range" else "full_range"
      
      intersection <- tryCatch(
        st_intersection(tiger_geom, pa_union),
        error = function(e) NULL
      )
      
      if (is.null(intersection) ||
          length(intersection) == 0 ||
          all(is.na(st_geometry(intersection))) ||
          all(st_is_empty(intersection))) {
        
        area_km2 <- 0
        
      } else {
        
        intersection <- intersection[!is.na(st_geometry(intersection)), ]
        intersection <- intersection[!st_is_empty(intersection), ]
        area_km2     <- as.numeric(sum(st_area(intersection)) / 1e6)
        
      }
      
      results <- results |>
        add_row(iso3          = iso3,
                range_type    = extent_label,
                boundary_type = "protected_area",
                area_km2      = area_km2,
                percentage    = NA_real_)
    }
    
  } else {
    
    for (extent_label in c("extant_range", "full_range")) {
      results <- results |>
        add_row(iso3          = iso3,
                range_type    = extent_label,
                boundary_type = "protected_area",
                area_km2      = 0,
                percentage    = NA_real_)
    }
  }
  
  # ---------------------------------------------------------------------------
  # 3h. Total range area within country (extant_range and full_range)
  # ---------------------------------------------------------------------------
  
  for (tiger_type in c("extant", "full")) {
    
    tiger_geom   <- if (tiger_type == "extant") tiger_extant_clip else tiger_full_clip
    extent_label <- if (tiger_type == "extant") "extant_range" else "full_range"
    
    if (is.null(tiger_geom) ||
        nrow(tiger_geom) == 0 ||
        all(is.na(st_geometry(tiger_geom))) ||
        all(st_is_empty(tiger_geom))) {
      
      area_km2 <- 0
      
    } else {
      
      tiger_geom <- tiger_geom[!is.na(st_geometry(tiger_geom)), ]
      tiger_geom <- tiger_geom[!st_is_empty(tiger_geom), ]
      area_km2   <- as.numeric(sum(st_area(tiger_geom)) / 1e6)
      
    }
    
    results <- results |>
      add_row(iso3          = iso3,
              range_type    = extent_label,
              boundary_type = "total",
              area_km2      = area_km2,
              percentage    = NA_real_)
  }
  
  cat("  Completed:", iso3, "\n")
  
}

########################################################################
### STEP 4: Replace AND_ back to AND for joining with other datasets ###
########################################################################

results <- results %>%
  mutate(iso3 = if_else(iso3 == "AND_", "AND", iso3))

##############################################################
### STEP 5: Calculate percentage based on total range area ###
##############################################################

### Extract total range area per iso3 and range_type as denominator ###
total_range_areas <- results %>%
  filter(boundary_type == "total",
         range_type    != "full_country") %>%
  select(iso3, range_type, total_area_km2 = area_km2)

### Join denominator back to full results and calculate percentage ###
results <- results %>%
  left_join(total_range_areas, by = c("iso3", "range_type")) %>%
  mutate(percentage = case_when(range_type    == "full_country" ~ NA_real_,
                                boundary_type == "total"        ~ 100,
                                is.na(total_area_km2)           ~ NA_real_,
                                total_area_km2 == 0             ~ 0,
                                TRUE ~ (area_km2 / total_area_km2) * 100)) %>%
  select(-total_area_km2)

print("Percentages calculated")

######################################
### STEP 6: Sort and round results ###
######################################

results <- results %>%
  arrange(iso3, range_type, boundary_type) %>%
  mutate(area_km2   = round(area_km2, 4),
         percentage = round(percentage, 4))

print("Results cleaned")

###########################################################
### STEP 7: Join country names from Country.Code.Lookup ###
###########################################################

results <- results %>%
  left_join(Country.Code.Lookup,
            by = c("iso3" = "ISO3")) %>%
  select(iso3, CountryName, range_type, boundary_type, area_km2, percentage)

print("Country names joined")

#############################
### STEP 8: Export to CSV ###
#############################
# write.csv(results, str_c(outWS.Stats, "Range_Summary_20260618.csv"), row.names = FALSE, na = "")  # export NA as empty string instead of "NA"
print("Data exported")

# Script end time:
print(str_c("Script ended: ", Sys.time()))
print(str_c("Total runtime: ", round(difftime(Sys.time(), script.start.time, units = "hours"), 2), " hours"))

print("SCRIPT COMPLETE")