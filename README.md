# NYC 311 Service Delay Analysis

**Where do NYC 311 service requests wait longest, and where is the delay concentrated?**

An end-to-end analysis of 3.65 million NYC 311 requests from 2025, built with **MySQL, Python (Jupyter) and Power BI**.

> Independent analysis of public NYC Open Data. Not affiliated with or endorsed by the City of New York.

![Overview dashboard](dashboard/screenshots/page1_overview.png)

---

## Key findings

- **Delay is concentrated.** 27 of 553 agency–complaint–borough combinations (under 5%) account for half of all excess waiting time.
- **HPD (housing) accounts for about 40% of excess waiting time** (171M of about 431M hours), followed by DOB (21.5%) and DPR (16.1%).
- **NYPD handles about 44% of analysed requests but only 0.5% of the excess waiting time.** Volume is not the same as delay.
- **HPD hotspots:** Unsanitary Condition (Manhattan, Bronx, Brooklyn) and Plumbing (Manhattan, Bronx) hold about 29% of HPD's excess time while making up about 18% of its requests. Manhattan is slowest for both, with 90th-percentile waits of about 4 months.
- **DOT street lights** make up about 45% of DOT's excess time and appear in all four boroughs, which points to a citywide capacity issue and not one under-served borough.
- **Graffiti is the only complaint with official due dates** in the data: 43.5% of 16,260 requests closed after the due date (Queens 53%, Brooklyn 48%, Manhattan 36%, Bronx 27%).

### Recommendation

Within HPD, focus inspection capacity first on Unsanitary Condition and Plumbing complaints in Manhattan and the Bronx, then Brooklyn. This is a recommendation about **where delay is concentrated**, not a staffing plan: the dataset has no staffing data.

![Where the delay is](dashboard/screenshots/page2_where_delay_is.png)

---

## The question and the key decision

The original plan was to measure where the city misses its own targets. The data did not allow it: **only 0.45% of requests (16,614, almost all DSNY graffiti) have a due date.**

So I changed the question and my yardstick, and said so openly:

> For each agency and complaint type, how long does the city normally take, and where is it unusually slower than that?

- **Benchmark:** the median resolution time for that agency and complaint type.
- **Slow request:** takes more than twice the benchmark and at least one day longer.
- **Excess hours:** time beyond the benchmark, capped at that complaint type's 99th percentile so a few extreme cases don't dominate.
- This is my own yardstick, **not an official city target.**

---

## Data

- **Source:** [NYC Open Data, 311 Service Requests from 2020 to Present](https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9/about_data)
- **Scope:** requests created 1 January to 31 December 2025 (3,655,042 rows).
- **The raw file is not included** (it is far over GitHub's file size limit). Download it from the link above, filtered to the same dates.

### Data issues found and how I handled them

| Issue | Count | Handling |
|---|---|---|
| No closed date (still open) | 54,649 (1.5%) | Kept, no resolution time; reported by agency |
| Closed before created | 916 | Resolution time set to NULL |
| Borough "Unspecified" | 2,607 | Set to NULL |
| Missing coordinates | 50,147 | Kept, no map point |
| Coordinates outside NYC | 0 | None needed |
| Mixed-case complaint types | 190 types | Standardised (upper-case, trimmed) |
| Same complaint type under two agencies | e.g. Encampment (NYPD and DHS) | Benchmarks calculated per agency and complaint type |
| Probable duplicates (same agency, type, location, day) | 639,781 (17.5%) | Flagged and excluded; results unchanged when included |
| Date-only closing times | 104,819 (2.9%) | Flagged; DOB records days only |
| Missing due dates | 99.55% of requests | Benchmark approach (above) |

---

## Method

1. **Load:** raw CSV into MySQL as text, unchanged (`raw_311`).
2. **Profile:** SQL checks for nulls, bad dates, boroughs, coordinates, duplicates, repeated timestamps.
3. **Clean:** typed, standardised table with derived columns (`clean_311`). See `sql/02_clean.sql`.
4. **Analyse:** Jupyter notebook: volume, resolution time, benchmarks, borough comparison, Pareto of excess hours, robustness checks.
5. **Summarise:** small aggregated tables written back to MySQL (`sum_*`).
6. **Visualise:** Power BI dashboard on the summary tables only.

### Robustness checks

- Top-10 combinations are unchanged when duplicates are included.
- 8 of the top 10 stay in the top 10 using only the first half of 2025.
- Without date-only closings, 7 of the top 10 stay. The three that drop are DOB combinations, because DOB records closing dates only, so removing date-only closings removes most of DOB's data. DOB results are treated as day-level.

### Judgement calls, stated openly

- **Rule-driven types excluded:** Food Establishment, Smoking or Vaping, Mobile Food Vendor, Day Care, Non-Residential Heat, Cannabis Retailer, and Helicopter Noise close on fixed schedules (for example 60 days), so they measure a rule, not performance.
- **DPR Maintenance or Facility in Queens is flagged as a one-time backlog:** 45% of its requests closed in July–August 2026, and no other DPR category shows this. It is hidden by default on the dashboard and reported separately.
- **DOB Building/Use in Queens** shows a smaller spring 2026 closing push (about one in five closings), but most of the waiting happened earlier, so it stays in the analysis with a note.

---

## Limitations

1. The benchmark is each complaint type's own typical time, not an official target.
2. Only graffiti has official due dates.
3. There is no staffing data, so shares are shares of **delay**, not of staff.
4. Many requests are still open for EDC (45.5%), TLC (15.5%), DPR (14.3%) and DHS (11.7%), so their delays are understated.
5. DOB records closing dates without times, so its waits are measured in whole days.
6. Duplicate removal uses my own rule (same agency, complaint, descriptor, location and day). Different apartments in one building can be separate cases, so this may remove some real requests, though rankings did not change when duplicates were included.
7. One year of data only. Seasonal patterns could not be compared year over year.

---

## Dashboard

Five pages: Overview, Where the delay is, HPD recommendation, Supporting findings, Limits.

| | |
|---|---|
| ![HPD](dashboard/screenshots/page3_hpd.png) | ![Supporting](dashboard/screenshots/page4_supporting.png) |

A PDF export is in `dashboard/`.

---

## Repository structure

```
sql/              profiling and cleaning queries
notebooks/        analysis notebook
dashboard/        Power BI file, PDF export, screenshots
assets/           project badge
requirements.txt  Python packages
```

## How to reproduce

1. Download the 2025 data from the link above and place the CSV in a local `data/` folder (not committed).
2. Install MySQL 8 or newer and create a database: `CREATE DATABASE nyc311;`
3. `pip install -r requirements.txt`
4. Set your MySQL password as an environment variable named `MYSQL_PASSWORD`.
5. Run the notebook from the top: load, profile, clean, analyse, summary tables.
6. Open the `.pbix` in Power BI Desktop (Windows) and point it to your local MySQL database.

## Tools

MySQL 8 · Python (pandas, SQLAlchemy, PyMySQL, matplotlib, seaborn) · Jupyter · Power BI Desktop

## Author

**Mididoddi Sai Karthik** · [GitHub](https://github.com/saikarthik011101-pro) · [LinkedIn](https://www.linkedin.com/in/sai-karthik-230290300))
