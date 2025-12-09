USE [YouTube Shorts];

==================================================================================
-- DASHBOARD 1 — Performance Overview
==================================================================================
-- Total Views
SELECT SUM(views) AS total_views 
FROM shorts;

-- Average Views per video
SELECT ROUND(AVG(CAST(views AS FLOAT)),0) AS avg_views_per_video 
FROM shorts;

-- Total likes/Comments/Share
SELECT 
	SUM(likes) AS total_likes, 
	SUM(comments) AS total_comments, 
	SUM(shares) AS total_shares
FROM shorts;

-- Average Engagement Rate
SELECT 
  ROUND(SUM(likes + comments + shares) * 1.0 / NULLIF(SUM(views),0),2) AS overall_engagement_rate
FROM shorts;

-- Views Distribution
SELECT
  CASE
    WHEN views < 50000 THEN '<50k'
    WHEN views BETWEEN 50000 AND 99999 THEN '50k-99k'
    WHEN views BETWEEN 100000 AND 199999 THEN '100k-199k'
    WHEN views BETWEEN 200000 AND 299999 THEN '200k-299k'
    WHEN views BETWEEN 300000 AND 399999 THEN '300k-399k'
    WHEN views BETWEEN 400000 AND 499999 THEN '400k-499k'
    ELSE '500k+'
  END AS views_bin,
  COUNT(*) AS videos
FROM shorts
GROUP BY 
  CASE
    WHEN views < 50000 THEN '<50k'
    WHEN views BETWEEN 50000 AND 99999 THEN '50k-99k'
    WHEN views BETWEEN 100000 AND 199999 THEN '100k-199k'
    WHEN views BETWEEN 200000 AND 299999 THEN '200k-299k'
    WHEN views BETWEEN 300000 AND 399999 THEN '300k-399k'
    WHEN views BETWEEN 400000 AND 499999 THEN '400k-499k'
    ELSE '500k+'
  END
ORDER BY MIN(CASE
    WHEN views < 50000 THEN 0
    WHEN views BETWEEN 50000 AND 99999 THEN 1
    WHEN views BETWEEN 100000 AND 199999 THEN 2
    WHEN views BETWEEN 200000 AND 299999 THEN 3
    WHEN views BETWEEN 300000 AND 399999 THEN 4
    WHEN views BETWEEN 400000 AND 499999 THEN 5
    ELSE 6 END);

-- Enagagement Rate Distribution
WITH VideoRates AS (
    -- Step 1: Calculate the engagement rate once
    SELECT
        ((likes + comments + shares) * 1.0) / NULLIF(views, 0) AS engagement_rate
    FROM shorts
)
SELECT
    -- Step 2: Define the bins based on the pre-calculated rate
    CASE
        WHEN engagement_rate IS NULL OR engagement_rate < 0.01 THEN '<1%'
        WHEN engagement_rate BETWEEN 0.01 AND 0.04 THEN '1-4%'
        WHEN engagement_rate BETWEEN 0.04 AND 0.1 THEN '4-10%'
        ELSE '10%+'
    END AS engagement_rate_bin,
    COUNT(*) AS videos
FROM VideoRates
GROUP BY
    -- Step 3: Group by the *exact* CASE statement (or its corresponding numeric order)
    CASE
        WHEN engagement_rate IS NULL OR engagement_rate < 0.01 THEN '<1%'
        WHEN engagement_rate BETWEEN 0.01 AND 0.04 THEN '1-4%'
        WHEN engagement_rate BETWEEN 0.04 AND 0.1 THEN '4-10%'
        ELSE '10%+'
    END
ORDER BY
    -- Step 4: Order by a corresponding numeric value to ensure correct categorical order
    MIN(CASE
        WHEN engagement_rate IS NULL OR engagement_rate < 0.01 THEN 0
        WHEN engagement_rate BETWEEN 0.01 AND 0.04 THEN 1
        WHEN engagement_rate BETWEEN 0.04 AND 0.1 THEN 2
        ELSE 3
    END);

-- Views by Category
SELECT DISTINCT
  category,
  ROUND(AVG(CAST(views AS FLOAT)) OVER (PARTITION BY category),0) AS avg_views,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY views) OVER (PARTITION BY category),0) AS median_views,
  COUNT(*) OVER (PARTITION BY category) AS videos
FROM shorts
ORDER BY avg_views DESC;

--Views by Upload Hour
SELECT 
	upload_hour, 
	COUNT(*) AS videos, 
	AVG(views) AS avg_views
FROM shorts
GROUP BY upload_hour
ORDER BY upload_hour;

-- Top 10 Videos
SELECT TOP(10)
  video_id, title, category, duration_sec, hashtags_count, views, likes, comments, shares,
  CAST((likes+comments+shares) AS FLOAT)/NULLIF(views,0) AS engagement_rate
FROM shorts
ORDER BY views DESC;

==================================================================================
-- DASHBOARD 2 — Category Insights
==================================================================================
-- Average views by Category
WITH CategoryStats AS (
    -- Step 1: Calculate ALL the necessary values (aggregates and window function)
    SELECT
        category,
        views, -- Needed for the PERCENTILE_CONT calculation
        COUNT(*) OVER (PARTITION BY category) AS videos,
        AVG(views) OVER (PARTITION BY category) AS avg_views,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY views) OVER (PARTITION BY category) AS median_views
    FROM dbo.shorts
)
SELECT DISTINCT
    category,
    videos,
    avg_views,
    median_views
FROM CategoryStats
ORDER BY avg_views DESC;

-- Average Enagagement Rate by Category
SELECT category,
       ROUND(AVG(CAST(likes + comments + shares AS FLOAT) / NULLIF(views,0)),1) AS avg_engagement_rate,
       AVG(hashtags_count) AS avg_hashtags,
       AVG(duration_sec) AS avg_duration
FROM shorts
GROUP BY category
ORDER BY avg_engagement_rate DESC;

--Average views,Engagement Rate, Count
SELECT category,
       AVG(views) AS avg_views,
       round(AVG(CAST(likes + comments + shares AS FLOAT) / NULLIF(views,0)),1) AS avg_engagement_rate,
       COUNT(*) AS video_count
FROM shorts
GROUP BY category;

-- Category vs Views Distribution
SELECT DISTINCT
  category,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY views) OVER (PARTITION BY category) AS q1,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY views) OVER (PARTITION BY category) AS median,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY views) OVER (PARTITION BY category) AS q3,
  MIN(views) OVER (PARTITION BY category) AS min_views,
  MAX(views) OVER (PARTITION BY category) AS max_views
FROM dbo.shorts
ORDER BY category;

--  Viarl percentage by Category
;WITH p90 AS (
  SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY views) OVER () AS p90 FROM dbo.shorts
),
marked AS (
  SELECT s.*,
         (SELECT TOP(1) p90 FROM p90) AS p90
  FROM dbo.shorts s
)
SELECT category,
       COUNT(*) AS videos,
       SUM(CASE WHEN views >= p90 THEN 1 ELSE 0 END) AS viral_count,
       ROUND(100.0 * SUM(CASE WHEN views >= p90 THEN 1 ELSE 0 END) / COUNT(*),0) AS viral_pct
FROM marked
GROUP BY category
ORDER BY viral_pct DESC;

==================================================================================
-- DASHBOARD 3 — Upload Time Analysis
==================================================================================
-- Average Views by Upload hour line
SELECT  upload_hour, 
		COUNT(*) AS videos, 
		AVG(views) AS avg_views
FROM dbo.shorts
GROUP BY upload_hour
ORDER BY upload_hour;

-- Enagagement Rate by Upload hour
SELECT upload_hour,
       AVG(CAST(likes+comments+shares AS FLOAT)/NULLIF(views,0)) AS avg_engagement_rate,
       COUNT(*) AS videos
FROM dbo.shorts
GROUP BY upload_hour
ORDER BY upload_hour;

-- Upload Hour Distribution
SELECT upload_hour, COUNT(*) AS videos
FROM dbo.shorts
GROUP BY upload_hour
ORDER BY videos DESC;

-- Viarl Videos by upload hour
;WITH p90 AS (
  SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY views) OVER () AS p90 FROM dbo.shorts
),
marked AS (
  SELECT s.*, (SELECT TOP(1) p90 FROM p90) AS p90
  FROM dbo.shorts s
)
SELECT upload_hour,
       COUNT(*) AS total_videos,
       SUM(CASE WHEN views >= p90 THEN 1 ELSE 0 END) AS viral_videos,
       AVG(CASE WHEN views >= p90 THEN views END) AS avg_viral_views
FROM marked
GROUP BY upload_hour
ORDER BY avg_viral_views DESC;

-- Categoory vs Hours
SELECT category, upload_hour, AVG(views) AS avg_views, COUNT(*) AS count_videos
FROM dbo.shorts
GROUP BY category, upload_hour
ORDER BY category, upload_hour;






