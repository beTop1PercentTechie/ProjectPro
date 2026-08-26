# Canteen Food Waste Intelligence

A complete data analysis project that looks at canteen food service records to understand **how much food is wasted, why it happens, and what can be done about it**.

---

## What is this project about?

Every day, a canteen plans meals, prepares food, and serves people. But the amount planned rarely matches the amount actually eaten — and the difference becomes waste. This waste costs money and resources.

This project takes real (simulated) canteen service data and answers simple but important questions:

- How much food is being wasted overall?
- Which food items waste the most?
- Which meal (breakfast, lunch, snacks, dinner) wastes the most?
- Why does the waste happen — is it overproduction, low demand, poor quality, etc.?
- Are there certain days or months where waste is higher?
- Can we spot the "worst offenders" so management can fix them first?

---

## What's inside this project?

| File | What it is |
|---|---|
| `Canteen_Food_Waste_Intelligence_MESSY.xlsx` | The raw dataset — intentionally messy (missing values, typos, wrong entries) just like real-world data |
| `Canteen_Food_Waste_Intelligence.ipynb` | The full analysis notebook — cleaning, statistics, charts, and business recommendations |

---

## What does the dataset contain?

Each row is one meal-service record. Here's what the columns mean:

| Column | Meaning |
|---|---|
| Record_ID | A unique ID for each entry |
| Date | Date the meal was served |
| Meal_Type | Breakfast, Lunch, Snacks, or Dinner |
| Menu_Item | The food item served (e.g., Dal Rice, Poha) |
| Planned_Meals | How many meals were planned |
| Meals_Prepared | How many meals were actually cooked |
| Meals_Served | How many meals were actually given to people |
| Meals_Leftover | Meals cooked but not served |
| Food_Prepared_kg | Total weight of food cooked |
| Food_Consumed_kg | Total weight of food actually eaten |
| Food_Wasted_kg | Total weight of food thrown away |
| Waste_Type | What kind of waste it was (plate waste, leftover, etc.) |
| Waste_Reason | Why it happened (overproduction, low demand, etc.) |
| Waste_Cost | How much money the wasted food is worth |
| Attendance_Count | How many people showed up |
| Demand_Forecast | How many meals were expected to be needed |

**Note:** This dataset is deliberately "dirty" — it has missing values, typos, wrong data types, and impossible numbers (like negative meals). This is done on purpose so the project can demonstrate real-world data cleaning, the way messy data actually looks in practice.

---

## What does the analysis notebook actually do?

Think of the notebook as a story told in stages:

### 1. Understanding the Problem
Explains why food waste matters and what questions we want answered.

### 2. Checking the Data's Health
Before trusting any number, we check: How much data is missing? Are there duplicate entries? Are there typos like "Snaks" instead of "Snacks"? Are there impossible values like negative attendance?

### 3. Cleaning the Data
We fix everything found above — step by step, and every fix is explained in plain language, so nothing happens silently.

### 4. Creating Useful New Numbers
We calculate helpful ratios like:
- **Waste Rate** – what % of food cooked went to waste
- **Utilization Rate** – what % of cooked food was actually served
- **Forecast Error** – how far off the demand prediction was from real attendance

### 5. Exploring the Data
Using charts and statistics, we look at:
- What a "typical" waste day looks like
- How much waste varies day to day
- Whether a few extreme days are responsible for most of the waste
- Which food items and meal types waste the most
- Whether waste is increasing, decreasing, or steady over time

### 6. Finding Patterns and Relationships
We check things like:
- Does preparing more food lead to more waste?
- Do certain meal types waste more than others?
- Are there specific combinations (e.g., "Dinner + Overproduction") that waste the most?

### 7. Flagging High-Risk Cases
We identify the specific records that are the "worst of the worst" — high waste, high cost, and low efficiency all at once — so management has a short list to investigate directly.

### 8. Turning Numbers into Business Advice
Every important finding is explained in four simple parts:
- **What we found**
- **What proves it** (the number/chart)
- **What it means for the canteen**
- **What action to take**

### 9. Final Recommendations
Clear, prioritized action items — ranked High, Medium, or Low priority — based on what the data actually shows, not guesswork.

---

## What tools were used?

Only simple, widely-used Python tools:

- **pandas** – for handling and cleaning the data
- **numpy** – for numerical calculations
- **matplotlib** – for creating charts
- **seaborn** – for more advanced/prettier charts

No machine learning or advanced statistical libraries were used. This keeps the project transparent, easy to follow, and easy to explain to anyone — even without a data science background.

---

## How to use this project

1. **Download both files** and keep them in the same folder.
2. Open `Canteen_Food_Waste_Intelligence.ipynb` in Jupyter Notebook or VS Code.
3. Make sure you have the required libraries installed:
   ```bash
   pip install pandas numpy matplotlib seaborn jupyter openpyxl
   ```
4. Run the notebook from top to bottom — every cell will run and show its own chart, table, or explanation.

---

## Who is this for?

- Students learning real-world data analysis
- Anyone building a data analysis portfolio project
- Canteen or food-service managers wanting a template to analyze their own waste data
- Anyone who wants to see how raw, messy data becomes a clean, professional, business-ready report

---

## Important Notes

- All numbers, findings, and charts in the notebook come **directly from the dataset** — nothing is invented.
- Since the dataset is simulated, the findings are meant to demonstrate the *method* of analysis, not real-world canteen statistics.
- The project is intentionally honest about its limits — wherever something can't be proven with the data or tools used, the notebook says so clearly instead of overstating the results.

---

## Future Improvements

This project could be extended with:
- Demand forecasting to predict future meal needs
- Formal statistical significance testing
- Cost-driver analysis (ingredient cost vs labor cost)
- Real-time waste tracking dashboards