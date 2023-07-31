--ANALYSIS OF DEMOCRATIC HOUSE CHALLENGERS 2016-2020
-- Making a table of all the dem challenger winners

SELECT res.[FEC ID], max(res.[ELECTION YEAR]) as YEAR_ELECTED, [CANDIDATE NAME]
INTO dem_challenger_winners
FROM [election_results16-20] res
	JOIN [candidate_master15-24] mas
		ON res.[FEC ID] = mas.CAND_ID
WHERE [(I) Incumbent Indicator] = 0
	AND res.PARTY = 'D'
	AND res.[GE WINNER INDICATOR] = 'W'
	AND mas.CAND_ICI = 'C'
	AND mas.CAND_ELECTION_YR = res.[ELECTION YEAR]
GROUP BY res.[FEC ID], res.[CANDIDATE NAME]
ORDER BY [CANDIDATE NAME]

-- Making a table of all the dem challenger losers

SELECT res.[FEC ID], res.[CANDIDATE NAME]
INTO dem_challenger_losers
FROM [election_results16-20] res
	JOIN [candidate_master15-24] mas on mas.CAND_ID = res.[FEC ID]
WHERE mas.CAND_ICI = 'C'
	AND mas.CAND_PTY_AFFILIATION = 'DEM'
	AND mas.CAND_ELECTION_YR <> 2022
	AND mas.CAND_ELECTION_YR <> 2024 
	AND res.[GE WINNER INDICATOR] is null
GROUP BY res.[FEC ID], res.[CANDIDATE NAME]

-- Creating overall incumbent loser table

SELECT res.[FEC ID], max(res.[ELECTION YEAR]) as YEAR_LOST, [CANDIDATE NAME], max(cand.TTL_RECEIPTS) as total_raised, cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
INTO losing_incumbents
FROM [election_results16-20] res
	JOIN [candidate_master15-24] mas
		ON res.[FEC ID] = mas.CAND_ID
	JOIN [candidate15-24] cand
		ON cand.CAND_ID = res.[FEC ID]
WHERE [(I) Incumbent Indicator] = 1
	AND res.[GE WINNER INDICATOR] is null
	AND mas.CAND_ICI = 'I'
	AND mas.CAND_ELECTION_YR = res.[ELECTION YEAR]
GROUP BY res.[FEC ID], res.[CANDIDATE NAME], cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
ORDER BY [CANDIDATE NAME]

-- Comparing newly created tables to determine percent of dem challengers that win
-- BELOW: OVERALL WIN PERCENTAGE OF DEM HOUSE CHALLENGERS FROM 2016, 2018, AND 2020

SELECT CAST (COUNT(DISTINCT(win.[CANDIDATE NAME])) as numeric) / (CAST (COUNT(DISTINCT(lose.[CANDIDATE NAME])) as numeric) + CAST (COUNT(DISTINCT(win.[CANDIDATE NAME])) as numeric)) * 100 as win_percent
FROM dem_challenger_winners win
	FULL OUTER JOIN dem_challenger_losers lose ON lose.[FEC ID] = win.[FEC ID]

-- creating view to store this for later visualization
CREATE VIEW percent_challenger_winners  as
SELECT CAST (COUNT(DISTINCT(win.[CANDIDATE NAME])) as numeric) / (CAST (COUNT(DISTINCT(lose.[CANDIDATE NAME])) as numeric) + CAST (COUNT(DISTINCT(win.[CANDIDATE NAME])) as numeric)) * 100 as win_percent
FROM dem_challenger_winners win
	FULL OUTER JOIN dem_challenger_losers lose ON lose.[FEC ID] = win.[FEC ID]
GO

 -- How much do Dem. Challengers who WIN typically raise on average versus their incumbent opponents

SELECT win.[FEC ID], win.[CANDIDATE NAME], win.YEAR_ELECTED, max(cand.TTL_RECEIPTS) total_raised, cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
INTO winners_amount_raised_and_district
FROM dem_challenger_winners win
	LEFT JOIN [candidate15-24] cand on cand.CAND_ID = win.[FEC ID]
WHERE cand.CAND_ICI = 'C'
GROUP BY win.[FEC ID], win.[CANDIDATE NAME], win.YEAR_ELECTED, cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
ORDER BY [CANDIDATE NAME]

SELECT AVG(win.total_raised) as challenger_winner_avg_raise, AVG(lose.total_raised) as incumbent_loser_avg_raise
FROM winners_amount_raised_and_district win
FULL OUTER JOIN losing_incumbents lose
	ON lose.CAND_OFFICE_DISTRICT_ = win.CAND_OFFICE_DISTRICT_
	AND lose.CAND_OFFICE_ST_ = win.CAND_OFFICE_ST_
	AND lose.YEAR_LOST = win.YEAR_ELECTED
WHERE win.[CANDIDATE NAME] is not null -- this takes out any mistaken info from the FEC that lists a candidate as a challenger in an open seat
AND lose.[CANDIDATE NAME] is not null -- this takes out any incumbent dems that lost to rep challengers

-- creating view to store this for later visualization
CREATE VIEW winning_challenger_raised_avg_versus_incumbent_loser_avg  as
SELECT AVG(win.total_raised) as challenger_winner_avg_raise, AVG(lose.total_raised) as incumbent_loser_avg_raise
FROM winners_amount_raised_and_district win
FULL OUTER JOIN losing_incumbents lose
	ON lose.CAND_OFFICE_DISTRICT_ = win.CAND_OFFICE_DISTRICT_
	AND lose.CAND_OFFICE_ST_ = win.CAND_OFFICE_ST_
	AND lose.YEAR_LOST = win.YEAR_ELECTED
WHERE win.[CANDIDATE NAME] is not null -- this takes out any mistaken info from the FEC that lists a candidate as a challenger in an open seat
AND lose.[CANDIDATE NAME] is not null -- this takes out any incumbent dems that lost to rep challengers
GO

-- How much do losing dem challengers raise on average? + district info

SELECT lose.[FEC ID], lose.[CANDIDATE NAME], max(cand.TTL_RECEIPTS) total_raised, cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
INTO losers_amount_raised_and_district
FROM dem_challenger_losers lose
	LEFT JOIN [candidate15-24] cand on cand.CAND_ID = lose.[FEC ID]
WHERE cand.CAND_ICI = 'C'
GROUP BY lose.[FEC ID], lose.[CANDIDATE NAME], cand.CAND_OFFICE_DISTRICT_, cand.CAND_OFFICE_ST_, cand.CAND_PTY_AFFILIATION_
ORDER BY [CANDIDATE NAME] 

SELECT avg(total_raised) average_losing_fundraising
FROM losers_amount_raised_and_district

-- creating view to store this for later visualization
CREATE VIEW losing_challengers_raised_average as
SELECT avg(total_raised) average_losing_fundraising
FROM losers_amount_raised_and_district
GO

-- Breakdown of dem challenger losers fundraising

SELECT COUNT(DISTINCT(lose.[CANDIDATE NAME])) losing_challengers, count(DISTINCT(lose.[CANDIDATE NAME])) * 1.0 / sum(count(DISTINCT(lose.[CANDIDATE NAME]))) over () * 100 AS percentage,
CASE 
	WHEN total_raised BETWEEN 100000 AND 499999 THEN '100K-499K'
	WHEN total_raised BETWEEN 500000 AND 999999 THEN '500K-999K'
	WHEN total_raised >= 1000000 THEN 'Over 1 mil'
	ELSE 'Under 100K'
END raised_category
FROM losers_amount_raised_and_district lose
GROUP BY 
CASE 
	WHEN total_raised BETWEEN 100000 AND 499999 THEN '100K-499K'
	WHEN total_raised BETWEEN 500000 AND 999999 THEN '500K-999K'
	WHEN total_raised >= 1000000 THEN 'Over 1 mil'
	ELSE 'Under 100K'
END 
ORDER BY losing_challengers desc

-- creating view to store this for later visualization
CREATE VIEW Breakdown_of_challenger_loser_fundraising as
SELECT COUNT(DISTINCT(lose.[CANDIDATE NAME])) losing_challengers, count(DISTINCT(lose.[CANDIDATE NAME])) * 1.0 / sum(count(DISTINCT(lose.[CANDIDATE NAME]))) over () * 100 AS percentage,
CASE 
	WHEN total_raised BETWEEN 100000 AND 499999 THEN '100K-499K'
	WHEN total_raised BETWEEN 500000 AND 999999 THEN '500K-999K'
	WHEN total_raised >= 1000000 THEN 'Over 1 mil'
	ELSE 'Under 100K'
END raised_category
FROM losers_amount_raised_and_district lose
GROUP BY 
CASE 
	WHEN total_raised BETWEEN 100000 AND 499999 THEN '100K-499K'
	WHEN total_raised BETWEEN 500000 AND 999999 THEN '500K-999K'
	WHEN total_raised >= 1000000 THEN 'Over 1 mil'
	ELSE 'Under 100K'
END 
GO
--ORDER BY losing_challengers desc

-- State breakdown of winners

SELECT CAND_OFFICE_ST_, COUNT(CAND_OFFICE_ST_) as total_challenger_winners
FROM winners_amount_raised_and_district
GROUP BY CAND_OFFICE_ST_
ORDER BY total_challenger_winners desc

-- creating view to store this for later visualization

CREATE VIEW state_breakdown_of_challenger_winners  as
SELECT CAND_OFFICE_ST_, COUNT(CAND_OFFICE_ST_) as total_challenger_winners
FROM winners_amount_raised_and_district
GROUP BY CAND_OFFICE_ST_
--ORDER BY total_challenger_winners desc
GO