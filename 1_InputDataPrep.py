import arcpy
import os
arcpy.env.overwriteOutput = True

# Written by Ellie Linden in June 2026

# The purpose of this script is to prepare the input datasets for the big cat statistical intersection analyses. This includes processing the following datasets:
# - Ranges (IUCN)
# - KBAs (BirdLife)
# - Protected Areas (UNEP-WCMC WDPA & National Tiger Conservation Authority)
# - Country boundaries (FAO GAUL & Survey of India Ministry of Science & Technology)

# Note for re-running the script:
# - This script assumes all output folders and workspaces exist before it is run. A way to achieve this is to make a copy of the "AnalysisOutputs" folder (specify the date in the new base output folder), then delete the underlying files. Given the number of split files in some of the geodatabases, it could make sense to delete those geodatabases entirely then create new ones.

#####################
### Set Variables ###
#####################

# ---------------------------------------------------------------------------- #
# ---  Base Workspaces, Projected Coordinate System & Generalize Tolerance --- #
# ---------------------------------------------------------------------------- #
inWS = "E:\\Ellie\\BigCats\\Data\\"
outWS = "E:\\Ellie\\BigCats\\AnalysisOutputs_2026_June\\"
out_projectedcoordinate_system='PROJCRS["World_Mollweide",BASEGEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433]],CONVERSION["Mollweide",METHOD["Mollweide"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0]],CS[Cartesian,2],AXIS["Easting (X)",east,ORDER[1]],AXIS["Northing (Y)",north,ORDER[2]],LENGTHUNIT["Meter",1.0],ID["Esri","54009"]]'
generalize_tolerance_100m = "100 Meters"

# ------------------------------------ #
# --- Input & Intermedite Datasets --- #
# ------------------------------------ #

### Country Boundaries ###
CountryBoundaries = inWS + r"CountryCodes\CountryBoundaries\GAUL_2024\Unzipped\GAUL_2024_L1.shp"
CountryBoundaries_prj = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_prj"
CountryBoundaries_prj_diss = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_prj_diss"
CountryBoundaries_prj_diss_select = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_prj_diss_select"
input_countries = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_prj_diss_select_generalized100m" # "input_countries" variable used within the loop
CountryBoundaries_select_where_clause= "iso3_code <> 'IND'"
CountryBoundaries_Check_Geometry_original_output = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_CheckGeometry_original"
CountryBoundaries_Check_Geometry_repaired_output = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_CheckGeometry_repaired"
CountryBoundaries_prj_select_diss = outWS + r"CountryBoundaries\GlobalBoundaries_FAO2024_Intermediate.gdb\CountryBoundaries_prj_select_diss"
India_boundary = inWS + r"CountryCodes\CountryBoundaries\IndiaBoundary\Inputs\Unzipped\File_503759_cd6d9fba586b40a79235544f75e70eb1\91\STATE_BOUNDARY.shp"
India_boundary_prj = outWS + r"CountryBoundaries\IndiaBoundary_Intermediate\IndiaBoundary_prj"
India_boundary_diss = outWS + r"CountryBoundarySplitting\BoundariesSplit.gdb\IND"
country_field = "iso3_code"

### Ranges ###
Tiger_extant = inWS + r"Ranges\IUCN\Version_emailed_on_20260421\Inputs\Unzipped\panthera_tigris_extant.shp"
Tiger_extant_prj = outWS + r"Ranges\Version_emailed_on_20260421\Intermediate\panthera_tigris_extant_prj.shp"
Tiger_full = inWS + r"Ranges\IUCN\Version_emailed_on_20260421\Inputs\Unzipped\panthera_tigris_full.shp"
Tiger_full_prj = outWS + r"Ranges\Version_emailed_on_20260421\Intermediate\panthera_tigris_full_prj.shp"

### KBAs ###
KBAs = inWS + r"KBAs\2026_03\Inputs\Unzipped\KBAsGlobal_2025_September_02\KBAsGlobal_2025_September_02_POL.shp"
KBAs_prj = outWS + r"KBAs\Intermediate\KBAs_prj.shp"
KBAs_Check_Geometry_original_output = outWS + r"KBAs\Intermediate\KBAs_CheckGeometry_original.csv"
KBAs_Check_Geometry_repaired_output = outWS + r"KBAs\Intermediate\KBAs_CheckGeometry_repaired.csv"
KBAs_prj_diss = outWS + r"KBAs\Intermediate\KBAs_prj_diss.shp"
KBAs_prj_diss_generalized100m = outWS + r"KBAs\Intermediate\KBAs_prj_diss_generalized100m.shp"

### Protected Areas ###
WDPA_ProtectedAreas = inWS + r"ProtectedAreas\WDPA\version_2026_04\Inputs\Unzipped\WDPA_Apr2026_Public.gdb\WDPA_poly_Apr2026"
WDPA_ProtectedAreas_prj = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj"
WDPA_ProtectedAreas_Check_Geometry_original_output = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_CheckGeometry_original"
WDPA_ProtectedAreas_Check_Geometry_repaired_output = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_CheckGeometry_repaired"
WDPA_ProtectedAreas_prj_eraseIndia = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj_eraseIndia"
WDPA_ProtectedAreas_select_where_clause_Pre2020 = "STATUS <> 'Proposed' And STATUS_YR <= 2020 And ISO3 NOT LIKE '%IND%' And IUCN_CAT IN ('II', 'IV')"
WDPA_ProtectedAreas_prj_select_Pre2020 = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj_select_Pre2020"
WDPA_ProtectedAreas_prj_select_Pre2020_generalized100m = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj_select_Pre2020_generalized100m"
WDPA_ProtectedAreas_select_where_clause_all = "STATUS <> 'Proposed' And ISO3 NOT LIKE '%IND%' And IUCN_CAT IN ('II', 'IV')"
WDPA_ProtectedAreas_prj_select_all = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj_select_all"
WDPA_ProtectedAreas_prj_select_all_generalized100m = outWS + r"ProtectedAreas\WDPA\WDPA_Intermediate.gdb\WDPA_prj_select_all_generalized100m"
India_ProtectedAreas = inWS + r"ProtectedAreas\IndiaProtectedAreas_NTCA\Unzipped\PA_poly705_wgs84_dd.shp"
India_ProtectedAreas_prj = outWS + r"ProtectedAreas\NTCA\Intermediate\India_ProtectedAreas_prj.shp"
India_ProtectedAreas_Check_Geometry = outWS + r"ProtectedAreas\NTCA\Intermediate\India_ProtectedAreas_CheckGeometry_original.csv"
India_ProtectedAreas_select_where_clause = "DESIG IN ('National Park', 'Sanctuary')"
India_ProtectedAreas_prj_select = outWS + r"ProtectedAreas\NTCA\Intermediate\India_ProtectedAreas_prj_select.shp"
ProtectedAreas_merged_Pre2020 = outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_merged_Pre2020"
ProtectedAreas_merged_all = outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_merged_all"

ProtectedAreas_SplitMerged_Pre2020 =  outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_dissolved_merged_Pre2020"
ProtectedAreas_SplitMerged_all =  outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_dissolved_merged_all"
ProtectedAreas_merged_dissolved2_Pre2020 =  outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_Pre2020_dissolved2"
ProtectedAreas_merged_dissolved2_all =  outWS + r"ProtectedAreas\Merged\ProtectedAreasMerged.gdb\ProtectedAreas_all_dissolved2"

# ------------------------------- #
# --- Split Output Workspaces --- #
# ------------------------------- #
split_boundary_gdb = outWS + r"CountryBoundarySplitting\BoundariesSplit.gdb"
KBAs_clipped = outWS + r"CountryBoundarySplitting\KBAs_clipped.gdb"
ProtectedAreas_clipped_Pre2020 = outWS + r"CountryBoundarySplitting\ProtectedAreas_clipped_Pre2020.gdb"
ProtectedAreas_clipped_dissolved_Pre2020 = outWS + r"CountryBoundarySplitting\ProtectedAreas_clipped_dissolved_Pre2020.gdb"
ProtectedAreas_clipped_all = outWS + r"CountryBoundarySplitting\ProtectedAreas_clipped_all.gdb"
ProtectedAreas_clipped_dissolved_all = outWS + r"CountryBoundarySplitting\ProtectedAreas_clipped_dissolved_all.gdb"

print("Variables set")

################################################################
### Initial Prep (Project, Repair Geometry, Dissolve, Merge) ###
################################################################

# -------------------------- #
# --- Country Boundaries --- #
# -------------------------- #

### Global: Project ###
arcpy.management.Project(in_dataset=CountryBoundaries,
                         out_dataset=CountryBoundaries_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

print("Country boundaries projected")

### Global: Dissolve ###
arcpy.analysis.PairwiseDissolve(CountryBoundaries_prj, CountryBoundaries_prj_diss, "gaul0_code", None, "MULTI_PART")
print("Country boundary dissolved")

### Global: Re-Join Fields ###
arcpy.management.JoinField(CountryBoundaries_prj_diss, "gaul0_code", CountryBoundaries_prj, "gaul0_code", "continent;disp_en;gaul0_name;iso3_code;map_code")
print("Fields re-joined")

### Global: Select ###
arcpy.analysis.Select(CountryBoundaries_prj_diss, CountryBoundaries_prj_diss_select, where_clause=CountryBoundaries_select_where_clause)
print("Country boundary selected")

### Global: Copy and Generalize ###
arcpy.management.Copy(CountryBoundaries_prj_diss_select, input_countries)
print("Country boundaries copied before generalizing")

arcpy.edit.Generalize(in_features=input_countries,
                      tolerance=generalize_tolerance_100m)
print("Country boundaries generalized")

### Global: Check Geometry (original) ###
arcpy.management.CheckGeometry(input_countries, CountryBoundaries_Check_Geometry_original_output)

### Global: Repair Geometry ###
arcpy.management.RepairGeometry(input_countries)

### Global: Check Geometry (repaired) ###
arcpy.management.CheckGeometry(input_countries, CountryBoundaries_Check_Geometry_repaired_output)

print("Country boundary geometry checked and repaired")

# Dissolve ###
# NOTE: This dataset is not needed for the loop, but rather a step in the R code that requires the area of all countries.
arcpy.analysis.PairwiseDissolve(input_countries, CountryBoundaries_prj_select_diss)
print("Country boundaries dissolved")

### India: Project ###
arcpy.management.Project(in_dataset=India_boundary,
                         out_dataset=India_boundary_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='PROJCRS["LCC_WGS84",BASEGEOGCRS["GCS_WGS_1984",DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433]],CONVERSION["Lambert_Conformal_Conic",METHOD["Lambert_Conformal_Conic"],PARAMETER["False_Easting",4000000.0],PARAMETER["False_Northing",4000000.0],PARAMETER["Central_Meridian",80.0],PARAMETER["Standard_Parallel_1",12.472944],PARAMETER["Standard_Parallel_2",35.172806],PARAMETER["Scale_Factor",1.0],PARAMETER["Latitude_Of_Origin",24.0]],CS[Cartesian,2],AXIS["Easting (X)",east,ORDER[1]],AXIS["Northing (Y)",north,ORDER[2]],LENGTHUNIT["Meter",1.0]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

### India: Dissolve ###
# NOTE: This exports the dissolved polygon directly to the geodatabase used in the loop.
arcpy.management.Dissolve(India_boundary_prj, India_boundary_diss)
print("India country boundary projected and dissolved.")

# -------------- #
# --- Ranges --- #
# -------------- #

### Project: Extant range ###
arcpy.management.Project(in_dataset=Tiger_extant,
                         out_dataset=Tiger_extant_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='GEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433],ID["EPSG","4326"]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

### Project: Full range ###
arcpy.management.Project(in_dataset=Tiger_full,
                         out_dataset=Tiger_full_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='GEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433],ID["EPSG","4326"]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

print("Ranges projected")

# ------------ #
# --- KBAs --- #
# ------------ #

### Project ###
arcpy.management.Project(in_dataset=KBAs,
                         out_dataset=KBAs_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='GEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433],ID["EPSG","4326"]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

print("KBAs projected")

### Check Geometry (original) ###
arcpy.management.CheckGeometry(KBAs_prj, KBAs_Check_Geometry_original_output)

### Repair Geometry ###
arcpy.management.RepairGeometry(KBAs_prj)

### Check Geometry (repaired) ###
arcpy.management.CheckGeometry(KBAs_prj, KBAs_Check_Geometry_repaired_output)

print("KBA geometry checked and repaired")

### Dissolve ###
arcpy.analysis.PairwiseDissolve(KBAs_prj, KBAs_prj_diss)
print("KBAs dissolved")

### Copy and Generalize KBA Boundaries ###
arcpy.management.Copy(KBAs_prj_diss, KBAs_prj_diss_generalized100m)
print("KBAs copied before generalizing")

arcpy.edit.Generalize(in_features=KBAs_prj_diss_generalized100m,
                      tolerance=generalize_tolerance_100m)

print("KBAs generalized")

# ----------------------- #
# --- Protected Areas --- #
# ----------------------- #

# NOTE: There needs to be a version of the protected area dataset that represents a snapshot in 2020 (to be used for the Species Conservation Landscapes intersection), as well as "all" protected areas, i.e. those included in the most recent snapshot that meet filtering criteria to be used for the GBIF/range intersections.

# WDPA: Project ###
arcpy.management.Project(in_dataset=WDPA_ProtectedAreas,
                         out_dataset=WDPA_ProtectedAreas_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                        in_coor_system='GEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433],ID["EPSG","4326"]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")
print("Proteced areas projected")

### WDPA: Check Geometry (original) ###
arcpy.management.CheckGeometry(WDPA_ProtectedAreas_prj, WDPA_ProtectedAreas_Check_Geometry_original_output)
print("Geometry checked (original)")

### WDPA: Repair Geometry ###
arcpy.management.RepairGeometry(WDPA_ProtectedAreas_prj)
print("Geometry repaired")

### WDPA: Check Geometry (repaired) ###
arcpy.management.CheckGeometry(WDPA_ProtectedAreas_prj, WDPA_ProtectedAreas_Check_Geometry_repaired_output)
print("Geometry checked (repaired)")

### WDPA: Erase India ###
arcpy.analysis.PairwiseErase(WDPA_ProtectedAreas_prj, India_boundary_diss, WDPA_ProtectedAreas_prj_eraseIndia, None)
print("India erased")

### WDPA: Select (Pre 2020) ###
arcpy.analysis.Select(WDPA_ProtectedAreas_prj_eraseIndia, WDPA_ProtectedAreas_prj_select_Pre2020, where_clause=WDPA_ProtectedAreas_select_where_clause_Pre2020)
print("Protected Areas selected")

### WDPA: Copy and Generalize (Pre 2020) ###
arcpy.management.Copy(WDPA_ProtectedAreas_prj_select_Pre2020, WDPA_ProtectedAreas_prj_select_Pre2020_generalized100m)
print("WDPA (Pre 2020) copied before generalizing")

arcpy.edit.Generalize(in_features=WDPA_ProtectedAreas_prj_select_Pre2020_generalized100m,
                      tolerance=generalize_tolerance_100m)
print("WDPA (Pre 2020) generalized")

### WDPA: Select (all) ###
arcpy.analysis.Select(WDPA_ProtectedAreas_prj_eraseIndia, WDPA_ProtectedAreas_prj_select_all, where_clause=WDPA_ProtectedAreas_select_where_clause_all)
print("Protected Areas selected")

### WDPA: Copy and Generalize (all) ###
arcpy.management.Copy(WDPA_ProtectedAreas_prj_select_all, WDPA_ProtectedAreas_prj_select_all_generalized100m)
print("WDPA (all) copied before generalizing")

arcpy.edit.Generalize(in_features=WDPA_ProtectedAreas_prj_select_all_generalized100m,
                      tolerance=generalize_tolerance_100m)
print("WDPA (all) generalized")

### India (NTCA): Project ###
arcpy.management.Project(in_dataset=India_ProtectedAreas,
                         out_dataset=India_ProtectedAreas_prj,
                         out_coor_system=out_projectedcoordinate_system,
                         transform_method=None,
                         in_coor_system='GEOGCRS["GCS_WGS_1984",DYNAMIC[FRAMEEPOCH[1990.5],MODEL["AM0-2"]],DATUM["D_WGS_1984",ELLIPSOID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],CS[ellipsoidal,2],AXIS["Latitude (lat)",north,ORDER[1]],AXIS["Longitude (lon)",east,ORDER[2]],ANGLEUNIT["Degree",0.0174532925199433],ID["EPSG","4326"]]',
                         preserve_shape="NO_PRESERVE_SHAPE",
                         max_deviation=None,
                         vertical="NO_VERTICAL")

### India (NTCA): Check Geometry ###
arcpy.management.CheckGeometry(India_ProtectedAreas_prj, India_ProtectedAreas_Check_Geometry)

### India (NTCA): Select ###
arcpy.analysis.Select(in_features=India_ProtectedAreas_prj,
                      out_feature_class=India_ProtectedAreas_prj_select,
                      where_clause=India_ProtectedAreas_select_where_clause)
print("India protected areas selected")

### India (NTCA): Add & Calculate Field ###
arcpy.management.AddField(India_ProtectedAreas_prj_select, "ISO3", "TEXT")
arcpy.management.CalculateField(India_ProtectedAreas_prj_select, "ISO3", expression='"IND"', expression_type="PYTHON3")
print("India protected areas projected, geometry checked, ISO3 field added/calculated")

### Merge WDPA & India (NTCA) Protected Areas (Pre-2020) ###
arcpy.management.Merge([WDPA_ProtectedAreas_prj_select_Pre2020_generalized100m, India_ProtectedAreas_prj_select], ProtectedAreas_merged_Pre2020)
print("WDPA & India protected areas merged")

### Merge WDPA & India (NTCA) Protected Areas (all) ###
arcpy.management.Merge([WDPA_ProtectedAreas_prj_select_all_generalized100m, India_ProtectedAreas_prj_select], ProtectedAreas_merged_all)
print("WDPA & India protected areas merged")

##############################################################################
### Split Country Boundaries & Loop through to Clip Protected Areas & KBAs ###
##############################################################################

# NOTE: Given India had a separate boundary, to reduce double-counting due to overlaps, a list was made of the ISO3 codes which where then looped through to clip the KBA/protected area datasets to each separate country. These clipped datasets were then utilized for the range intersection analysis (which did not have built-in country splits).

### ── Build list of unique ISO3 codes ───────────────────────────────────────────
iso3_list = list(sorted(set(row[0] for row in arcpy.da.SearchCursor(input_countries, [country_field]))))

print(f"Found {len(iso3_list)} countries")

### Replace reserved SQL keywords in iso3_list before looping (to account for the country of Andorra, which has an ISO3 of "AND" which is a reserved SQL keyword)
iso3_list = ["AND_" if iso3 == "AND" else iso3 for iso3 in iso3_list]

### Append "IND" to the list (since India isn't included in the "input_countries" dataset)
iso3_list.append("IND")

# ── Loop through each country ──────────────────────────────────────────────────
for iso3 in iso3_list:

    # Determine safe output name for reserved SQL keywords 
    safe_name = "AND_" if iso3 == "AND_" else iso3
    original_iso3 = "AND" if iso3 == "AND_" else iso3

    print(f"\nProcessing: {original_iso3}")

    # ── Export individual country boundary to split_boundary_gdb ───────────
    country_fc = os.path.join(split_boundary_gdb, safe_name)

    if original_iso3 == "IND":
        print(f"  Country boundary already exists, skipping Select: IND")
    else:
        sql_query = f"{country_field} = '{original_iso3}'"
        arcpy.analysis.Select(input_countries, country_fc, sql_query)
        print(f"  Country boundary exported: {safe_name}")

    # ── Clip KBAs to country boundary ──────────────────────────────────────
    kba_clipped_fc = os.path.join(KBAs_clipped, f"KBA_{iso3}")
    arcpy.analysis.PairwiseClip(KBAs_prj_diss_generalized100m, country_fc, kba_clipped_fc)
    arcpy.management.AddField(kba_clipped_fc, country_field, "TEXT", field_length=3)
    arcpy.management.CalculateField(kba_clipped_fc, country_field, f'"{original_iso3}"')
    print(f"  KBAs clipped: KBA_{iso3}")

    # ── Clip Protected Areas (Pre-2020) to country boundary ────────────────────────────
    pa_clipped_fc = os.path.join(ProtectedAreas_clipped_Pre2020, f"PA_{iso3}")
    arcpy.analysis.PairwiseClip(ProtectedAreas_merged_Pre2020, country_fc, pa_clipped_fc)
    arcpy.management.AddField(pa_clipped_fc, country_field, "TEXT", field_length=3)
    arcpy.management.CalculateField(pa_clipped_fc, country_field, f'"{original_iso3}"')
    print(f"  Protected Areas clipped: PA_{iso3}")

    # ── Dissolve clipped Protected Areas (Pre-2020) ──────────────────────────
    pa_dissolved_fc = os.path.join(ProtectedAreas_clipped_dissolved_Pre2020, f"PA_diss_{iso3}")
    arcpy.management.RepairGeometry(pa_clipped_fc)
    arcpy.management.Dissolve(pa_clipped_fc, pa_dissolved_fc)
    arcpy.management.AddField(pa_dissolved_fc, country_field, "TEXT", field_length=3)
    arcpy.management.CalculateField(pa_dissolved_fc, country_field, f'"{original_iso3}"')
    print(f"  Protected Areas dissolved: PA_diss_{iso3}")

    # ── Clip Protected Areas (all) to country boundary ───────────────────────
    pa_clipped_fc = os.path.join(ProtectedAreas_clipped_all, f"PA_{iso3}")
    arcpy.analysis.PairwiseClip(ProtectedAreas_merged_all, country_fc, pa_clipped_fc)
    arcpy.management.AddField(pa_clipped_fc, country_field, "TEXT", field_length=3)
    arcpy.management.CalculateField(pa_clipped_fc, country_field, f'"{original_iso3}"')
    print(f"  Protected Areas clipped: PA_{iso3}")

    # ── Dissolve clipped Protected Areas (all) ───────────────────────────────
    pa_dissolved_fc = os.path.join(ProtectedAreas_clipped_dissolved_all, f"PA_diss_{iso3}")
    arcpy.management.RepairGeometry(pa_clipped_fc)
    arcpy.management.Dissolve(pa_clipped_fc, pa_dissolved_fc)
    arcpy.management.AddField(pa_dissolved_fc, country_field, "TEXT", field_length=3)
    arcpy.management.CalculateField(pa_dissolved_fc, country_field, f'"{original_iso3}"')
    print(f"  Protected Areas dissolved: PA_diss_{iso3}")
    
#########################################################
### Final Protected Area Processing: Merge & Dissolve ###
#########################################################

# ---------------- #
# --- Pre-2020 --- #
# ---------------- #
print("Merging and dissolving protected area feature classes (pre-2020)...")

### Set workspace and create list of feature classes ###
arcpy.env.workspace = ProtectedAreas_clipped_dissolved_Pre2020
pa_dissolved_fcs = arcpy.ListFeatureClasses()
pa_dissolved_fcs = [os.path.join(ProtectedAreas_clipped_dissolved_Pre2020, fc) for fc in pa_dissolved_fcs]

### Merge ###
arcpy.management.Merge(pa_dissolved_fcs, ProtectedAreas_SplitMerged_Pre2020)
print("Protected areas merged (pre-2020)")

### Dissolve to produce a single polgyon feature ###
arcpy.analysis.PairwiseDissolve(ProtectedAreas_SplitMerged_Pre2020, ProtectedAreas_merged_dissolved2_Pre2020)
print("Protected areas dissolved (pre-2020)")

# ----------- #
# --- All --- #
# ----------- #
print("Merging and dissolving protected area feature classes (all)...")

### Set workspace and create list of feature classes ###
arcpy.env.workspace = ProtectedAreas_clipped_dissolved_all
pa_dissolved_fcs = arcpy.ListFeatureClasses()
pa_dissolved_fcs = [os.path.join(ProtectedAreas_clipped_dissolved_all, fc) for fc in pa_dissolved_fcs]

### Merge ###
arcpy.management.Merge(pa_dissolved_fcs, ProtectedAreas_SplitMerged_all)
print("Protected areas merged (all)")

### Dissolve to produce a single polgyon feature ###
arcpy.analysis.PairwiseDissolve(ProtectedAreas_SplitMerged_all, ProtectedAreas_merged_dissolved2_all)
print("Protected areas dissolved (all)")

print("SCRIPT COMPLETE")
