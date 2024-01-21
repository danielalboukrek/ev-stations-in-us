# Electric Vehicle Charging Stations in the US

[SQL Queries](https://github.com/danielalboukrek/ev-stations-in-us/blob/main/EV_stations.sql) <br>
[Tableau Visualization](https://public.tableau.com/app/profile/daniel.alboukrek/viz/ElectricVehicleChargingStationsinUS/EVChargingStations)

## Project Overview
Integrated three open source datasets in SQL to create a Tableau dashboard that visualized and surfaced key insights regarding the availability of electric vehicle charging stations in the US.

## Data Sources
Primary dataset: https://afdc.energy.gov/data_download <br><br>
Dataset relating all US states to their corresponding FIPS code: https://www.census.gov/library/reference/code-lists/ansi.html#states <br><br>
Dataset relating all US zip codes to their respective states: https://www.census.gov/geographies/reference-files/time-series/geo/relationship-files.2010.html#par_textimage_674173622

## Tools
- SQL Server (T-SQL)
- Tableau

## Data Cleaning
- Dropped fields corresponding to deprecated variables (referring to the [data dictionary](https://afdc.energy.gov/data_download/alt_fuel_stations_format))
- Correctly formatted date fields
- Added new fields containing year that stations were opened, the presence of each type of EV connector, and whether stations are restricted or non-restricted
- Modified records with incorrect zip code data and null state data
- Deleted duplicate records

## Exploratory Data Analysis
Utilized SQL queries to explore the dataset and answer key questions, such as:
- How has the number of charging stations changed over time?
- Which connector types are most widely available?
- What are the most popular charging networks?
- Where are most stations located?

## Conclusions
1. California contains the most amount of stations and over four times as many stations as the state with the second-highest number of stations, New York.
2. The majority of stations are located in hotels or car dealerships.
3. Following the passage of the Bipartisan Infrastructure Law in 2021, the number of stations supporting the Tesla charging standard (NACS) has increased considerably, though most new stations that are opened still use the J1772 charging standard.

## Limitations
1. Different charger connectors would be more prevalent in other regions of the world, and so the J1772 connector is not as prevalent outside of North America. A future direction would be to expand the dataset to include other countries and compare which connectors are most prevalent by region.
2. While this project found that some of the most populous states in the US, including California and New York, have the most amount of charging stations, a future direction would be to explore which states have the most amount of stations per capita. Also, it would be interesting to explore the ratio between the number of electric vehicles registered and the number of charging stations available per state.
