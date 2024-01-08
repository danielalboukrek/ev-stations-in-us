/*

Project Title: Electric Vehicle Charging Stations in the US

Data downloaded from https://afdc.energy.gov/data_download
The data dictionary for this dataset can be found at https://afdc.energy.gov/data_download/alt_fuel_stations_format

*/

-------------------
-- Data Cleaning --
-------------------

SELECT *
FROM PortfolioProjects..AltFuelStations

-- Dropping fields corresponding to deprecated variables according to the data dictionary

SELECT Count(*)
FROM INFORMATION_SCHEMA.Columns
WHERE TABLE_NAME = 'AltFuelStations'

ALTER TABLE AltFuelStations
	DROP COLUMN "groups_with_access_code", "ng_fill_type_code", "ng_psi", "ng_vehicle_class", "cng_vehicle_class", "lng_vehicle_class"

-- Dropping fields containing data in French

ALTER TABLE AltFuelStations
	DROP COLUMN "rd_blends_French", "intersection_directions_French", "access_days_time_French", "bd_blends_French", "groups_with_access_code_French", "ev_pricing_French"

-- Deleting 2 records corresponding to EV stations located in India

DELETE FROM PortfolioProjects..AltFuelStations WHERE State = 'KA'
DELETE FROM PortfolioProjects..AltFuelStations WHERE ID = 309392

-- Converting datetime fields to date fields, since we don't have the time data

ALTER TABLE AltFuelStations
ADD Date_Last_Confirmed_Converted Date;

ALTER TABLE AltFuelStations
ADD Open_Date_Converted Date;

UPDATE PortfolioProjects..AltFuelStations
SET Date_Last_Confirmed_Converted = CONVERT(Date, Date_Last_Confirmed),
	Open_Date_Converted = CONVERT(Date, Open_Date);

ALTER TABLE AltFuelStations
	DROP COLUMN "Date_Last_Confirmed", "Open_Date"

-- Adding new field containing year that stations were opened

ALTER TABLE PortfolioProjects..AltFuelStations
ADD YearOpened Int;

UPDATE PortfolioProjects..AltFuelStations
SET YearOpened = YEAR(Open_Date_Converted);

SELECT ID, Open_Date_Converted, YearOpened
FROM PortfolioProjects..AltFuelStations
ORDER BY Open_Date_Converted desc, ID

-- Populating states that are null based on zip code data (Tables downloaded from https://www.census.gov/library/reference/code-lists/ansi.html#states and https://www.census.gov/geographies/reference-files/time-series/geo/relationship-files.2010.html#par_textimage_674173622)

ALTER TABLE PortfolioProjects..CountyZCTA
ADD StateName nvarchar(50)

UPDATE PortfolioProjects..CountyZCTA
SET PortfolioProjects..CountyZCTA.StateName = PortfolioProjects..StateFIPS.STATE
FROM PortfolioProjects..CountyZCTA
	JOIN PortfolioProjects..StateFIPS ON PortfolioProjects..CountyZCTA.STATE = PortfolioProjects..StateFIPS.STATEFP

UPDATE PortfolioProjects..AltFuelStations
SET PortfolioProjects..AltFuelStations.State = PortfolioProjects..CountyZCTA.StateName
FROM PortfolioProjects..AltFuelStations
	JOIN PortfolioProjects..CountyZCTA ON PortfolioProjects..AltFuelStations.ZIP = PortfolioProjects..CountyZCTA.ZCTA5
WHERE PortfolioProjects..AltFuelStations.State IS NULL

-- Manually fixing incorrect zip codes (using https://gps-coordinates.org/)

UPDATE PortfolioProjects..AltFuelStations
SET PortfolioProjects..AltFuelStations.ZIP = '04614'
WHERE ID = 258259

UPDATE PortfolioProjects..AltFuelStations
SET PortfolioProjects..AltFuelStations.ZIP = '91343'
WHERE ID = 225622

UPDATE PortfolioProjects..AltFuelStations
SET PortfolioProjects..AltFuelStations.ZIP = '99362'
WHERE ID = 250519

UPDATE PortfolioProjects..AltFuelStations
SET PortfolioProjects..AltFuelStations.ZIP = '92555'
WHERE ID = 229460

-- Splitting the EV_Connector_Types field into multiple columns

ALTER TABLE PortfolioProjects..AltFuelStations
ADD NEMA_1450 VARCHAR(1)
ALTER TABLE PortfolioProjects..AltFuelStations
ADD NEMA_515 VARCHAR(1);
ALTER TABLE PortfolioProjects..AltFuelStations
ADD NEMA_520 VARCHAR(1);
ALTER TABLE PortfolioProjects..AltFuelStations
ADD J1772 VARCHAR(1);
ALTER TABLE PortfolioProjects..AltFuelStations
ADD CCS VARCHAR(1);
ALTER TABLE PortfolioProjects..AltFuelStations
ADD CHAdeMO VARCHAR(1);
ALTER TABLE PortfolioProjects..AltFuelStations
ADD NACS VARCHAR(1);

WITH EV_CONNECTORS_CTE AS
(SELECT ID, EV_Connector_Types, NEMA_1450, NEMA_515, NEMA_520, J1772, CCS, CHAdeMO, NACS, VALUE AS ConnectorTypes
FROM PortfolioProjects..AltFuelStations
CROSS APPLY
string_split(EV_Connector_Types, ' ')
)

UPDATE EV_CONNECTORS_CTE
SET NEMA_1450 = CASE
					WHEN ConnectorTypes = 'NEMA1450' THEN 'Y'
					ELSE 'N'
				END,
	NEMA_515 = CASE
					WHEN ConnectorTypes = 'NEMA515' THEN 'Y'
					ELSE 'N'
				END,
	NEMA_520 = CASE
					WHEN ConnectorTypes = 'NEMA520' THEN 'Y'
					ELSE 'N'
				END,
	J1772 = CASE
					WHEN ConnectorTypes = 'J1772' THEN 'Y'
					ELSE 'N'
				END,
	CCS = CASE
					WHEN ConnectorTypes = 'J1772COMBO' THEN 'Y'
					ELSE 'N'
				END,
	CHAdeMO = CASE
					WHEN ConnectorTypes = 'CHADEMO' THEN 'Y'
					ELSE 'N'
				END,
	NACS = CASE
					WHEN ConnectorTypes = 'TESLA' THEN 'Y'
					ELSE 'N'
				END

-- Creating a field to indicate whether a station is restricted or non-restricted

ALTER TABLE PortfolioProjects..AltFuelStations
ADD Restricted VARCHAR(1)

UPDATE PortfolioProjects..AltFuelStations
SET Restricted = CASE
					WHEN Access_Code = 'public' AND Restricted_Access = 'false' THEN 'N'
					ELSE 'Y'
				END

-- Deleting duplicate records

WITH CTE([Fuel_Type_Code],
	[Station_Name], 
    [Status_Code], 
    [Latitude],
	[Longitude],
	[Owner_Type_Code],
	[Access_Code],
	[Facility_Type],
	[Date_Last_Confirmed_Converted],
	[Open_Date_Converted],
	[EV_Level1_EVSE_Num],
	[EV_Level2_EVSE_Num],
	[EV_DC_Fast_Count],
	[EV_Network],
	[EV_Connector_Types],
	[EV_On_Site_Renewable_Source],
	[Maximum_Vehicle_Class],
	[EV_Workplace_Charging],
    DuplicateCount)
AS (SELECT [Fuel_Type_Code],
	[Station_Name], 
    [Status_Code], 
    [Latitude],
	[Longitude],
	[Owner_Type_Code],
	[Access_Code],
	[Facility_Type],
	[Date_Last_Confirmed_Converted],
	[Open_Date_Converted],
	[EV_Level1_EVSE_Num],
	[EV_Level2_EVSE_Num],
	[EV_DC_Fast_Count],
	[EV_Network],
	[EV_Connector_Types],
	[EV_On_Site_Renewable_Source],
	[Maximum_Vehicle_Class],
	[EV_Workplace_Charging],
           ROW_NUMBER() OVER(PARTITION BY [Fuel_Type_Code],
	[Station_Name], 
    [Status_Code], 
    [Latitude],
	[Longitude],
	[Owner_Type_Code],
	[Access_Code],
	[Facility_Type],
	[Date_Last_Confirmed_Converted],
	[Open_Date_Converted],
	[EV_Level1_EVSE_Num],
	[EV_Level2_EVSE_Num],
	[EV_DC_Fast_Count],
	[EV_Network],
	[EV_Connector_Types],
	[EV_On_Site_Renewable_Source],
	[Maximum_Vehicle_Class],
	[EV_Workplace_Charging]
           ORDER BY ID) AS DuplicateCount
    FROM PortfolioProjects..AltFuelStations)
DELETE FROM CTE
WHERE DuplicateCount > 1 AND Fuel_Type_Code = 'Elec'

----------------------
-- Data Exploration --
----------------------

SELECT ID, City, State, Open_Date_Converted, YearOpened, Access_Code, Owner_Type_Code, EV_Level1_EVSE_Num, EV_Level2_EVSE_Num, EV_DC_Fast_Count, 
		EV_Connector_Types, EV_Network, EV_Pricing, EV_On_Site_Renewable_Source, Facility_Type, Restricted_Access, Maximum_Vehicle_Class, EV_Workplace_Charging
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC'

-- Number of EV charging stations available per year by EV connector type, grouped by restricted status

SELECT YearOpened, COUNT(*) AS NumPublicStations, Restricted,
SUM(CASE WHEN NEMA_1450 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_1450,
	SUM(CASE WHEN NEMA_515 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_515,
	SUM(CASE WHEN NEMA_520 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_520,
	SUM(CASE WHEN J1772 = 'Y' THEN 1 ELSE 0 END) AS countJ1772,
	SUM(CASE WHEN CCS = 'Y' THEN 1 ELSE 0 END) AS countCCS,
	SUM(CASE WHEN CHAdeMO = 'Y' THEN 1 ELSE 0 END) AS countCHAdeMO,
	SUM(CASE WHEN NACS = 'Y' THEN 1 ELSE 0 END) AS countNACS
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND YearOpened IS NOT NULL AND EV_Connector_Types IS NOT NULL
GROUP BY YearOpened, Restricted
ORDER BY YearOpened

-- Number of EV stations currently available per state

SELECT State, COUNT(State) AS StationsPerState
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC'
GROUP BY State
ORDER BY StationsPerState desc

Select *
FROM PortfolioProjects..AltFuelStations
WHERE State IS NULL

-- 10 most popular facility types

SELECT TOP 10 Facility_Type, COUNT(*) AS FacTypeCounts
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND Facility_Type IS NOT NULL
GROUP BY Facility_Type
ORDER BY FacTypeCounts desc

-- 10 most popular EV Networks

SELECT TOP 10 EV_Network, COUNT(EV_Network) AS NetworkCount
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND EV_Network IS NOT NULL AND EV_Network <> 'Non-Networked'
GROUP BY EV_Network
ORDER BY NetworkCount desc

--------------------
-- Creating Views --
--------------------

GO
CREATE VIEW StationsPerState AS
SELECT State, COUNT(State) AS StationsPerState
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC'
GROUP BY State

GO
CREATE VIEW TopFacilities AS
SELECT Facility_Type, COUNT(*) AS FacTypeCounts
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND Facility_Type IS NOT NULL
GROUP BY Facility_Type

GO
CREATE VIEW TopEVNetworks AS
SELECT EV_Network, COUNT(EV_Network) AS NetworkCount
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND EV_Network IS NOT NULL AND EV_Network <> 'Non-Networked'
GROUP BY EV_Network

GO
CREATE VIEW NewStations AS
SELECT YearOpened, COUNT(*) AS NumPublicStations, Restricted,
SUM(CASE WHEN NEMA_1450 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_1450,
	SUM(CASE WHEN NEMA_515 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_515,
	SUM(CASE WHEN NEMA_520 = 'Y' THEN 1 ELSE 0 END) AS countNEMA_520,
	SUM(CASE WHEN J1772 = 'Y' THEN 1 ELSE 0 END) AS countJ1772,
	SUM(CASE WHEN CCS = 'Y' THEN 1 ELSE 0 END) AS countCCS,
	SUM(CASE WHEN CHAdeMO = 'Y' THEN 1 ELSE 0 END) AS countCHAdeMO,
	SUM(CASE WHEN NACS = 'Y' THEN 1 ELSE 0 END) AS countNACS
FROM PortfolioProjects..AltFuelStations
WHERE Fuel_Type_Code = 'ELEC' AND YearOpened IS NOT NULL AND EV_Connector_Types IS NOT NULL
GROUP BY YearOpened, Restricted
