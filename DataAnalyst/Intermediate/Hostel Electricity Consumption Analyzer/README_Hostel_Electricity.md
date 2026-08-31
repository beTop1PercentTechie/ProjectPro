# Hostel Electricity Consumption Analyzer

A complete data analysis project that looks at hostel room-level electricity meter readings to understand **how much electricity is used, where it's concentrated, and what's driving the cost**.

---

## What is this project about?

Hostels have hundreds of rooms, each with its own electricity meter. Some rooms use a lot of power, some use very little — but without analysis, nobody really knows *why*. Is it because more people live there? Is it a faulty meter? Is one hostel just less efficient than another?

This project takes real (simulated) hostel electricity meter data and answers questions like:

- How much electricity is being used overall, and what does it cost?
- Which hostels, blocks, or room types consume the most?
- Does electricity use actually match how many people live in the room?
- Are there rooms with broken meters or billing mistakes?
- Is electricity use going up, down, or staying steady over time?
- Which rooms should be checked first if we want to cut down on waste?

---

## What's inside this project?

| File | What it is |
|---|---|
| `Hostel_Electricity_Consumption_Analyzer.xlsx` | The raw dataset — intentionally messy, just like real-world data |
| `Hostel_Electricity_Consumption_Analyzer.ipynb` | The full analysis notebook — cleaning, statistics, charts, and recommendations |

---

## What does the dataset contain?

Each row is one meter-reading record for one room. Here's what the important columns mean:

| Column | Meaning |
|---|---|
| Record_ID | A unique ID for each reading |
| Reading_Date | Date the meter was read |
| Hostel_Name / Hostel_Code | Which hostel the room belongs to |
| Block / Floor / Room_Number | Where exactly the room is located |
| Room_Type | Single, Double, Triple, or Dormitory |
| Occupancy_Count | How many students currently live in the room |
| Room_Capacity | How many students the room is designed for |
| Student_Type | UG, PG, PhD, or Research Scholar |
| Meter_ID | The electricity meter's unique ID |
| Previous_Reading_kWh / Current_Reading_kWh | Meter readings at the start and end of the period |
| Units_Consumed_kWh | Electricity actually used (Current − Previous) |
| Electricity_Rate_Per_kWh | The price charged per unit |
| Electricity_Cost | Total bill amount |
| Peak_or_OffPeak | Whether the reading falls in a peak or off-peak time slot |
| Appliance_Details | What appliances are in the room |
| Reading_Status | Normal, Estimated, Disputed, etc. |
| Maintenance_Status | Whether the meter/room electrical setup is OK or needs attention |
| Recorded_By | Who or what recorded the reading |

**Also included — on purpose — are a few columns that are NOT useful for this analysis:** `Warden_Name`, `WiFi_Available`, `Mess_Timing`, `Building_Color`, `Hostel_Contact_Number`, and `Remarks`. These are real hostel-related fields, but they have nothing to do with electricity consumption. They're included specifically so the project can demonstrate the practice of **identifying and removing irrelevant columns** during cleaning — something that happens all the time with real institutional data exports.

**Note:** Just like the earlier project, this dataset is deliberately "dirty" — it has missing values, typos, mixed-up text, impossible readings (like a meter going backwards), and duplicate records. This is on purpose, to practice real-world data cleaning.

---

## What does the analysis notebook actually do?

Think of it as a step-by-step story:

### 1. Understanding the Problem
Explains why analyzing electricity use matters and what questions we want answered.

### 2. Checking the Data's Health
We check: How much data is missing? Are there duplicate entries? Are there readings that don't make sense (like a room using negative electricity)? Are there columns that don't actually help the analysis?

### 3. Cleaning the Data
We fix everything found above, step by step, in plain language — including **removing the six irrelevant columns** mentioned earlier so they don't clutter the actual analysis.

### 4. Creating Useful New Numbers
We calculate helpful metrics like:
- **Consumption per Occupant** – electricity use divided by number of people in the room
- **Occupancy Utilization Rate** – how full the room is compared to its capacity
- **Cost Discrepancy** – whether the billed cost actually matches (units × rate)

### 5. Exploring the Data
Using charts and statistics, we look at:
- What "typical" electricity use looks like
- How much it varies from room to room
- Whether a few rooms are using way more than everyone else
- Which hostels and room types use the most
- Whether usage is trending up or down over time

### 6. Finding Patterns and Relationships
We check things like:
- Does more people in a room really mean more electricity used?
- Do certain room types use more power than others?
- Are peak-hour readings different from off-peak ones?

### 7. Flagging High-Risk Rooms
We identify specific rooms that are simultaneously high in usage, high in cost, and inefficient for their occupancy — a short list worth checking in person.

### 8. Turning Numbers into Business Advice
Every major finding is explained in four simple parts:
- **What we found**
- **What proves it** (the number/chart)
- **What it means for hostel management**
- **What action to take**

### 9. Final Recommendations
Clear, prioritized action items — ranked High, Medium, or Low priority — based on what the data actually shows.

---

## What tools were used?

Only simple, widely-used Python tools:

- **pandas** – for handling and cleaning the data
- **numpy** – for numerical calculations
- **matplotlib** – for creating charts
- **seaborn** – for more advanced/prettier charts

No machine learning or advanced statistical libraries were used, keeping the project transparent and easy to follow.

---

## How to use this project

1. **Download both files** and keep them in the same folder.
2. Open `Hostel_Electricity_Consumption_Analyzer.ipynb` in Jupyter Notebook or VS Code.
3. Make sure you have the required libraries installed:
   ```bash
   pip install pandas numpy matplotlib seaborn jupyter openpyxl
   ```
4. Run the notebook from top to bottom — every cell will show its own chart, table, or explanation.

---

## Who is this for?

- Students learning real-world data analysis
- Anyone building a data analysis portfolio project
- Hostel or facility managers wanting a template to analyze their own electricity data
- Anyone who wants to see how a messy institutional export (with useless columns and all) becomes a clean, professional, decision-ready report

---

## Important Notes

- All numbers, findings, and charts in the notebook come **directly from the dataset** — nothing is invented.
- Since the dataset is simulated, the findings demonstrate the *method* of analysis, not real-world hostel statistics.
- The project is honest about its limits — wherever something can't be proven with the data or tools used, the notebook says so clearly instead of overstating the results.

---

## Future Improvements

This project could be extended with:
- Forecasting future electricity demand
- Formal statistical significance testing
- Appliance-level energy tracking
- Weather-adjusted consumption analysis
- Real-time smart-meter dashboards

These aren't included here on purpose, since they need tools beyond the simple ones used in this project — but they're natural next steps.
