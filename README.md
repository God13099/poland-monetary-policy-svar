# Monetary Policy Transmission in Poland (1998–2025): A Structural VAR Analysis

**Author:** Liyuan Cao  
**Tools:** Stata (SVAR, Time-Series Analysis)  
**Methodology:** Structural Vector Autoregression (Sims, 1980)

---

## 1. Project Overview

This project investigates the dynamic relationship between output growth, inflation, and monetary policy in Poland. Using a **Structural Vector Autoregression (SVAR)** framework based on the identification strategy proposed by **Sims (1980)**, the study examines how shocks to short-term interest rates propagate through the Polish economy over time.

The analysis focuses on the transmission mechanism of monetary policy and evaluates its stability across different economic regimes, including the post-inflation-targeting period and the COVID-19 era.

---

## 2. Data Strategy & Engineering

A robust data pipeline was constructed to integrate multiple data sources and address structural breaks in economic reporting.

### 2.1 Data Sources

- **Primary Source:**  
  Macroeconomic indicators (Real GDP, CPI, Population) retrieved from the **St. Louis Federal Reserve Economic Data (FRED)** database.

- **Policy Instrument:**  
  The **3-month interbank rate (WIBOR 3M)** is used as a proxy for the monetary policy instrument.

### 2.2 Data Reconstruction & Processing

- **Gap Filling & Reconstruction:**  
  Inflation data for **2022–2025** was manually collected and merged to reconstruct the CPI index for recent quarters (**2024Q1–2025Q2**), ensuring that the model captures post-pandemic volatility.

- **Real GDP Per Capita:**  
  Annual population data was interpolated to quarterly frequency to construct real GDP per capita.

- **Variable Transformation:**  
  GDP growth and inflation are expressed as annualized quarterly rates using:

  400 × ln(ΔX)

  This transformation follows standard practice in the monetary policy literature.

---

## 3. Econometric Methodology

### 3.1 Stationarity & Diagnostics

All variables were tested for stationarity using **Augmented Dickey-Fuller (ADF)** tests:

| Variable      | Test Statistic | Significance |
|---------------|----------------|--------------|
| GDP Growth    | -5.034         | 1% level     |
| Inflation     | -2.972         | 1% level     |
| Interest Rate | -2.332         | 5% level     |

- **Lag Length Selection:**  
  Based on the **Akaike Information Criterion (AIC)** and **Final Prediction Error (FPE)**, a lag order of **4** was selected to capture quarterly dynamics.

---

### 3.2 Identification Strategy

The SVAR model employs a **recursive (Cholesky) identification scheme**, assuming that:

- Output and prices respond to interest rate shocks with a lag.
- The central bank observes contemporaneous output and inflation when setting interest rates.

The structural matrices are defined as:

$$
A = \begin{pmatrix}
1 & 0 & 0 \\
\cdot & 1 & 0 \\
\cdot & \cdot & 1
\end{pmatrix}, \quad
B = \begin{pmatrix}
\cdot & 0 & 0 \\
0 & \cdot & 0 \\
0 & 0 & \cdot
\end{pmatrix}
$$

---

## 4. Key Findings & Robustness Checks

To ensure robustness and policy relevance, the model is evaluated across multiple specifications:

- **Baseline Sample (2004–2025):**  
  Focuses on the post-inflation-targeting regime in Poland.

- **Pre-COVID Subsample (2004–2019):**  
  Isolates traditional monetary transmission channels from pandemic-related supply shocks.

- **Alternative Variable Ordering:**  
  Tests the sensitivity of Impulse Response Functions (IRFs) to an alternative recursive structure:  
  **Inflation → Interest Rate → GDP**

Across specifications, the results indicate a stable but time-varying transmission of monetary policy shocks to output and inflation.

---

## 5. How to Run the Project

1. Ensure **Stata** is installed.
2. Place the following files in the same directory:
   - `Project 2.do`
   - `inflacja.csv`
3. Run the `.do` file in Stata.
4. The script will generate:
   - Log file: `Poland_SVAR_Master.log`
   - Impulse Response Function (IRF) plots

---

## 6. Repository Structure

```text
.
├── Project 2.do
├── inflacja.csv
├── Poland_SVAR_Master.log
├── README.md
└── figures/
    └── irf_plots/
        ├── g1_main_clean.png
        ├── g2_alt.png
        ├── g3_full.png
        └── g4_precovid.png

