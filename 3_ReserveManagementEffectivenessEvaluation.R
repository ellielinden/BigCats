# rm(list=ls())

library(tidyverse)
library(sf)

# Written by Ellie Linden in May 2026
# Written using R version 4.4.2

# The purpose of this script is to clean India's tiger reserve management effectiveness evaluation (MEE) data. 

# Script start time:
script.start.time <- Sys.time()
print(str_c("Script started: ", script.start.time))

######################################
### Set Main Workspace & Variables ###
######################################

WS <- "C:/Users/C837410204/OneDrive - Colostate/Dashboards/BigCats/Data/MEE/2026/"
MEE.scores <- read.csv(str_c(WS,"Inputs/MEE_Scores_20260511/MEE_Scores_ToBeImported.csv"))
Spatial.Polygons <- st_read(str_c(WS, "Processing/TR_KML_Export.gdb"), layer = "TigerReserves")

### Create Score Crosswalk ###
MEE.score.crosswalk <- tibble(Score_rank = c("a_Excellent", "b_Very Good", "c_Good", "d_Fair", "e_Poor"),
                              # Set colors for dashboard list background
                              Score_color = c("#74add1", "#abd9e9", "#e0f3f8", "#fee090", "#d73027"))
##################
### Clean Data ###
##################

MEE.scores <- MEE.scores %>%
  # Strip hidden spaces and characters from character fields
  mutate(across(where(is.character), ~ str_squish(str_trim(.)))) %>%
  # Convert numeric fields to character, strip, then convert back (numeric fields can't have 'str_trim' or 'str_squish' applied)
  mutate(across(where(is.numeric), ~ as.numeric(str_squish(str_trim(as.character(.)))))) %>%
  # Create ReserveName_2 with corrections
  mutate(ReserveName_2 = case_when(ReserveName == "Annamalai" ~ "Anamalai",
                                   ReserveName == "Navegaon-Nagzira"  ~ "Nawegaon-Nagzira",
                                   ReserveName == "Ranthambhore" ~ "Ranthambore",
                                   ReserveName == "Sanjay -Dubri" ~ "Sanjay-Dubri",
                                   ReserveName == "Sathyamanglam" ~ "Sathyamangalam",
                                   TRUE ~ ReserveName)) %>% 
  select(ReserveName, ReserveName_2, Score_2006, Score_2010, Score_2014, Score_2018, Score_2022)

#########################################
### Check for Reserve Name Mismatches ###
#########################################

### Fix invalid geometry of spatial polygons ###
Spatial.Polygons <- Spatial.Polygons %>%
  # Drop Z and/or M coordinates
  st_zm(drop = TRUE, what = "ZM") %>% 
  # Fix duplicate vertices / invalid geometry
  st_make_valid()

### Get unique values from each dataframe & compare ###
spatial_names <- Spatial.Polygons %>% 
  distinct(TR_Name_2) %>% 
  rename(Name = TR_Name_2) %>% 
  mutate(Name = str_squish(Name))

mee_names.scores <- MEE.scores %>% 
  distinct(ReserveName_2) %>% 
  rename(Name = ReserveName_2) %>% 
  mutate(Name = str_squish(Name))

mee_comparison_names.scores <- MEE.scores %>% 
  distinct(ReserveName_2) %>% 
  rename(Name = ReserveName_2) %>% 
  mutate(Name = str_squish(Name))

only_in_mee.scores <- mee_names.scores %>%
  anti_join(spatial_names, by = "Name") %>%
  mutate(MEE = "Yes", SpatialPolygons = NA_character_)

only_in_spatial.scores <- spatial_names %>%
  anti_join(mee_names.scores, by = "Name") %>%
  mutate(MEE = NA_character_, SpatialPolygons = "Yes")

# Combine into one dataframe
mismatched_reserves.scores.vs.SpatialPolygons <- bind_rows(only_in_mee.scores, only_in_spatial.scores) %>%
  arrange(Name)

#########################################
### Process & Export Spatial Polygons ###
#########################################

### Join numeric MEE scores to spatial polygons ###
Spatial.Polygons.with.MEE.scores <- Spatial.Polygons %>%
  left_join(MEE.scores %>% select(ReserveName_2, starts_with("Score_")),
            by = c("TR_Name_2" = "ReserveName_2")) %>% 
  # Remove polygons with NA for all year fields (which are assumed to be added after the last MEE assessment)
  filter(!if_all(starts_with("Score_"), is.na)) %>% 
  # Define rank based on numeric thresholds
  mutate(Rank_2022 = case_when(Score_2022 < 50  ~ "e_Poor",
                               Score_2022 >= 50 & Score_2022 < 60 ~ "d_Fair",
                               Score_2022 >= 60 & Score_2022 < 75 ~ "c_Good",
                               Score_2022 >= 75 & Score_2022 < 90 ~ "b_Very Good",
                               Score_2022 >= 90 ~ "a_Excellent",
                               .default = NA_character_)) %>% 
  # Remove unneeded fields
  select(-Name, -FolderPath, -SymbolID, -AltMode, -Extruded, -Snippet, -PopupInfo, -Shape_Length, -Shape_Area)

### Project Spatial Polygons to Web Mercator to visualize on web map ###
Spatial.Polygons.with.MEE.scores <- Spatial.Polygons.with.MEE.scores %>%
  st_transform(crs = 3857)

### Export Spatial Polygons ###
# st_write(Spatial.Polygons.with.MEE.scores, dsn = str_c(WS, "Outputs/TR_MEE_Scores.gdb"), layer = "TigerReserves_with_MEE_scores_2006to2022_20260521", driver = "OpenFileGDB", append=FALSE)

##############################################
### Process & Export Data in "Long" Format ###
##############################################

### Pivot Score dataframe from wide to long ###
MEE.scores.long <- MEE.scores %>%
  pivot_longer(cols = starts_with("Score_"),
               names_to = "Year",
               values_to = "Score_num",
               names_prefix = "Score_") %>%
  mutate(Year = as.integer(Year),
         Rank = case_when(Score_num < 50  ~ "e_Poor",
                          Score_num  >= 50 & Score_num < 60 ~ "d_Fair",
                          Score_num >= 60 & Score_num < 75 ~ "c_Good",
                          Score_num >= 75 & Score_num < 90 ~ "b_Very Good",
                          Score_num >= 90 ~ "a_Excellent",
                          .default = NA_character_))

### Join dataframes & add new fields ###
MEE.df.long <- MEE.scores.long %>%
  mutate(CountryName = "India",
         ISO3 = "IND") %>%
  # Convert blanks to NA
  mutate(across(where(is.character), ~na_if(., ""))) %>%
  # Join crosswalk to add Score_rank_2 and Score_color
  left_join(MEE.score.crosswalk, by = c("Rank" = "Score_rank")) %>%
  # Identify Top 10 reserves by Score_num in the most recent year
  mutate(Top10 = if_else(ReserveName_2 %in% (filter(., Year == max(Year)) %>%
                                               slice_max(Score_num, n = 10) %>%
                                               pull(ReserveName_2)),
                         "Yes", "No")) %>%
  select(CountryName, ISO3, ReserveName_2, Year, Score_num, Rank, Score_color, Top10)

### Export dataframe ###
# write_csv(MEE.df.long, str_c(WS,"Outputs/MEE_ScoresRanks_long_20260521.csv"), na = "")

# Script end time:
print(str_c("Script ended: ", Sys.time()))
print(str_c("Total runtime: ", round(difftime(Sys.time(), script.start.time, units = "hours"), 2), " hours"))

print("SCRIPT COMPLETE")
