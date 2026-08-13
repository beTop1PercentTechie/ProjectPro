# India EV Revolution: Growth & Adoption Forecasting

[![Built with][badge-python]](https://www.python.org/) [![Language][badge-language]](https://jupyter.org/) [![Output][badge-output]](https://www.w3.org/html/) [![License][badge-license]](LICENSE)

A professional data analytics project analyzing and forecasting the growth of Electric Vehicle (EV) adoption across India using real-world charging session data.

---

## Table of Contents

- [Overview](#overview)
- [What This Project Does](#what-this-project-does)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Installation & Setup](#installation--setup)
- [How to Use](#how-to-use)
- [Project Structure](#project-structure)
- [Output Files](#output-files)
- [System Requirements](#system-requirements)
- [FAQ](#faq)
- [License](#license)

---

## Overview

This project provides comprehensive analysis of India's Electric Vehicle charging infrastructure and adoption patterns. We examine real charging session data to understand trends, patterns, and forecast future growth in EV adoption across India.

The analysis supports:
- Understanding EV charging behavior and patterns
- Developing growth forecasting models
- Analyzing regional adoption trends
- Planning infrastructure expansion

---

## What This Project Does

### 1. Data Loading
Imports real EV charging session data from CSV format into a structured format ready for analysis.

### 2. Data Exploration & Analysis
Automatically generates comprehensive data profiles that identify:
- Patterns and trends in the data
- Anomalies and data quality issues
- Correlations between different variables
- Statistical distributions

### 3. Report Generation
Creates interactive HTML reports with:
- Statistical summaries and key metrics
- Data visualizations and charts
- Missing value analysis
- Correlation matrices

### 4. Actionable Insights
Provides clean, analyzed data to support:
- Growth forecasting models
- Infrastructure planning decisions
- Policy recommendations

---

## Features

- **Automatic Data Profiling** - Complete data analysis without manual coding
- **Interactive HTML Reports** - Professional visualizations and statistics
- **Statistical Analysis** - Correlations, distributions, and data relationships
- **Data Quality Checks** - Comprehensive data validation and issue identification
- **Forecasting Ready** - Clean, analyzed data prepared for prediction models
- **Jupyter Notebook Format** - Fully customizable and reproducible analysis

---

## Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Python | 3.8+ | Core programming language |
| Pandas | 2.3.3 | Data manipulation and analysis |
| NumPy | 2.3.5 | Numerical computing |
| Matplotlib | 3.10.0 | Data visualization |
| ydata-profiling | 4.18.4 | Automated data exploration |
| Jupyter | 1.1.1 | Interactive notebook environment |

---

## Installation & Setup

### Step 1: Verify Python Installation

Ensure you have Python 3.8 or newer:

```bash
python --version
```

### Step 2: Create Virtual Environment (Recommended)

```bash
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate
```

### Step 3: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 4: Verify Installation

```bash
pip list
```

---

## How to Use

### Using Jupyter Notebook (Recommended)

1. Start Jupyter Notebook:
   ```bash
   jupyter notebook
   ```

2. Open `python.ipynb` in your web browser

3. Execute each cell sequentially using the Run button

4. View the generated `EV_Charging_Profiling_Report.html`

### From Terminal

```bash
python -m jupyter notebook python.ipynb
```

---

## Project Structure

```
India_EV_Revolution_Growth_Adoption_Forecasting/
│
├── data.csv                              # Raw EV charging session data
├── python.ipynb                          # Main analysis notebook
├── requirements.txt                      # Python package dependencies
├── EV_Charging_Profiling_Report.html     # Generated analysis report
├── .gitignore                            # Git configuration
└── README.md                             # Project documentation
```

---

## Output Files

### data.csv
Raw dataset containing EV charging session information with multiple attributes and metrics.

### EV_Charging_Profiling_Report.html
Interactive HTML report providing:
- Complete dataset overview and summary statistics
- Missing data analysis and patterns
- Data type validation and checks
- Variable correlations and relationships
- Sample data preview

**To view:** Open the HTML file directly in your web browser.

---

## System Requirements

- **Python Version:** 3.8 or newer
- **RAM:** Minimum 4GB (8GB recommended for large datasets)
- **Disk Space:** 500MB for dependencies and project data
- **Operating System:** Windows, macOS, or Linux
- **Web Browser:** Modern browser for viewing HTML reports

---

## FAQ

**Q: How do I add my own data?**

A: Replace `data.csv` with your own CSV file. Ensure column headers are clearly labeled and data is properly formatted.

**Q: How do I customize the analysis?**

A: Edit the cells in `python.ipynb` to modify parameters, add new analyses, or change visualizations.

**Q: Can I use this with different datasets?**

A: Yes. This framework works with any structured data in CSV format. Adjust column references as needed.

**Q: How long does analysis take?**

A: Processing time depends on dataset size, typically between 30 seconds to 5 minutes for standard datasets.

**Q: What Python version do I need?**

A: Python 3.8 or newer is required. We recommend Python 3.9 or higher for best compatibility.

---

## License

This project is provided as-is for educational and research purposes.

---

[badge-python]: https://img.shields.io/badge/Built%20with-Python-blue
[badge-language]: https://img.shields.io/badge/Language-Jupyter%20Notebook-orange
[badge-output]: https://img.shields.io/badge/Output-HTML%20Reports-green
[badge-license]: https://img.shields.io/badge/License-MIT-blue
