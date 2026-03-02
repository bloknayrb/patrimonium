---
name: personal-finance
description: "Use when working on AI system prompts, insight generation logic, financial categorization, or budget/goal/investment features. Provides budgeting methodology, passive index investing guidance, and financial planning frameworks. All advice is educational — recommend a certified financial planner for personalized guidance."
---

# Personal Finance Adviser

> All guidance is educational — ranges and frameworks rather than specific recommendations. For personalized advice, recommend a fee-only fiduciary financial advisor.

This skill consolidates three domains: budgeting, investing, and financial planning. Use it when building or modifying AI-related features in Patrimonium (system prompts, insight generation, financial analysis).

## Patrimonium Context

- **Money storage**: All amounts are integer cents (`$123.45` = `12345`). Use `int.toCurrency()` from `core/extensions/money_extensions.dart`.
- **Expenses are negative**: Income is positive `amountCents`, expenses are negative.
- **Database tables**: `Accounts`, `Transactions`, `Categories`, `Budgets`, `Goals`, `RecurringTransactions`, `Insights`, `Conversations`, `Messages`.
- **Budget table fields**: `id`, `categoryId`, `amountCents`, `periodType`, `startDate`, `endDate`, `rollover`, `rolloverAmountCents`, `alertThreshold`. No `name` or `spentAmountCents` — spending must be computed from transactions.
- **Category hierarchy**: 16 expense + 7 income parent categories with subcategories, seeded by `CategorySeeder`.
- **Account types**: 18 types in `core/constants/account_types.dart` (checking, savings, credit_card, brokerage, 401k, IRA, roth_ira, HSA, mortgage, etc.).
- **Insight generation**: `InsightGenerationService` sends a financial snapshot to the LLM and expects structured JSON back. See `domain/usecases/ai/insight_generation_service.dart`.
- **Financial context**: `FinancialContextBuilder` produces plain-text snapshots for LLM system prompts. See `domain/usecases/ai/financial_context_builder.dart`.

---

## Part 1: Budgeting

### Supported Budgeting Frameworks

**Zero-Based Budgeting (ZBB):** Every dollar of income is assigned a purpose. Income minus all allocations equals zero. When overspending occurs in one category, pull from another — "roll with the punches." Best for people who want full control and visibility.

**50/30/20 Rule:** Split after-tax income into needs (50%), wants (30%), and savings/debt (20%). "Needs" means obligations that don't go away if income drops: housing, utilities, groceries, insurance, minimum debt payments. In high-cost-of-living areas, the needs portion often exceeds 50% — adjust ratios rather than mislabeling wants as needs.

**Envelope Budgeting:** Assign spending caps to categories. When the envelope is empty, stop spending in that category until next period. Digital equivalent: category tracking with hard limits. Pairs well with ZBB for implementation.

**YNAB's Four Rules:**
1. Give every dollar a job (ZBB)
2. Embrace your true expenses (sinking funds)
3. Roll with the punches (adjust, don't abandon)
4. Age your money (spend last month's income)

See `references/budget-frameworks.md` for detailed methodology breakdowns.

### Transaction Categorization

Follow this sequence when processing transactions:

1. **Merchant normalization** — Strip transaction noise (SQ *, AMZN MKTP US*, PAYPAL *, check digits). See `references/merchant-categories.md` for patterns.
2. **Category assignment** — Match normalized merchants to categories using the merchant lookup table. Apply regex patterns for common prefixes.
3. **Ambiguity flagging** — Flag transactions that map to multiple possible categories (e.g., Walmart, Target, Costco, Amazon) for human review. Never silently guess on ambiguous items.

### Standard Budget Categories

- **Housing** — rent/mortgage, property tax, HOA, repairs/maintenance
- **Utilities** — electric, gas, water, internet, phone
- **Groceries** — supermarket purchases, meal ingredients
- **Transportation** — gas, car payment, insurance, maintenance, parking, public transit
- **Healthcare** — insurance premiums, copays, prescriptions, dental, vision
- **Debt Payments** — student loans, credit cards (above minimum), personal loans
- **Dining Out** — restaurants, coffee shops, takeout, delivery
- **Entertainment** — streaming, events, hobbies, games
- **Personal Care** — haircuts, toiletries, gym membership
- **Clothing** — apparel, shoes, accessories
- **Subscriptions** — software, memberships, recurring charges
- **Savings** — emergency fund, sinking funds, general savings
- **Gifts & Donations** — presents, charitable giving
- **Childcare** — daycare, school supplies, activities
- **Pets** — food, vet, grooming, supplies

### Sinking Funds

Irregular or annual expenses divided into monthly allocations. Prevent "surprise" large expenses from blowing the budget. Calculate monthly amount: annual cost / 12.

### Debt Payoff

- **Avalanche** — Pay minimums on all debts, throw extra money at the highest interest rate. Mathematically optimal: minimizes total interest paid.
- **Snowball** — Pay minimums on all debts, throw extra money at the smallest balance. Psychologically effective: quick wins build momentum.

---

## Part 2: Investing

### Bogleheads Core Principles

1. Develop a workable plan
2. Start investing early — time in market beats timing the market
3. Never bear too much or too little risk
4. Diversify with broad market index funds
5. Never try to time the market
6. Use index funds when possible
7. Keep costs low — every basis point matters
8. Minimize taxes — use tax-advantaged accounts strategically
9. Invest with simplicity — a three-fund portfolio captures the entire market
10. Stay the course — don't panic sell, don't chase performance

### Three-Fund Portfolio

| Fund | Purpose | Example (Vanguard) |
|------|---------|-------------------|
| US Total Stock Market | Domestic equity exposure | VTSAX / VTI |
| International Total Stock Market | Non-US equity exposure | VTIAX / VXUS |
| US Total Bond Market | Fixed income / stability | VBTLX / BND |

See `references/three-fund-portfolio.md` for brokerage-specific fund picks and allocation rationale.

### Tax-Advantaged Account Priority

1. **401(k) up to employer match** — Immediate 50-100% return
2. **HSA (if eligible)** — Triple tax advantage
3. **Roth IRA or Traditional IRA** — Tax-free growth or tax deduction now
4. **401(k) up to annual max** — Additional tax-deferred or Roth growth
5. **Taxable brokerage** — No tax advantage, but no restrictions

See `references/account-hierarchy.md` for Roth vs Traditional framework.
See `references/contribution-limits.md` for current IRS limits.

### Asset Allocation Guidelines

Age-based starting points:
- "Age in bonds" — conservative
- "Age minus 10 in bonds" — moderate
- "Age minus 20 in bonds" — aggressive

Within stocks — US vs International: global market cap weight is ~60% US / 40% international. Common simplification: 70/30 or 80/20.

### Rebalancing

- **Calendar**: Check annually or semi-annually
- **Threshold**: Rebalance when any asset class drifts >5% from target

Tax-efficient priority: (1) direct new contributions to underweight, (2) rebalance within tax-advantaged accounts, (3) sell in taxable only as last resort.

---

## Part 3: Financial Planning

### The Financial Priority Ladder

Work through stages in order:

1. **Stabilize Cash Flow** — Track income/expenses, build starter emergency fund ($1,000–$2,000)
2. **Capture Free Money** — 401(k) up to employer match
3. **Eliminate High-Rate Debt** — Pay off debt above ~6–8% interest
4. **Build Full Emergency Fund** — 3–6 months of essential expenses
5. **Fill Tax-Advantaged Space** — HSA → Roth IRA → 401(k) max → Mega backdoor Roth
6. **Medium-Rate Debt vs Investing** — Personal decision for 4–6% debt
7. **Taxable Investing and Beyond** — Brokerage accounts, low-rate debt is fine to carry

### Emergency Fund Sizing

| Situation | Suggested Range |
|-----------|----------------|
| Dual income, stable jobs, no dependents | 3 months |
| Single income, stable job | 3–4 months |
| Single income, dependents | 4–6 months |
| Variable income / commission | 6–9 months |
| Self-employed | 6–12 months |
| Pre-retirement (within 5 years) | 12–24 months |

"Months" means monthly essential expenses, not gross income.

### Life Event Triggers

Major life changes requiring financial plan review: new job, marriage, children, home purchase, job loss, inheritance, divorce, approaching retirement.

See `references/planning-checklist.md` for detailed checklists.

### When to Seek Professional Help

General rule: if the decision involves more than $50,000, has significant tax implications, or uncertainty remains after research — a professional consultation is worth the cost.

See `references/professional-referral-guide.md` for when to consult CFPs, CPAs, estate attorneys, and insurance specialists.

## References

- `references/budget-frameworks.md` — Detailed methodology for each budgeting framework
- `references/merchant-categories.md` — Merchant-to-category lookup table with regex patterns
- `references/account-hierarchy.md` — Tax-advantaged account priority with Roth vs Traditional framework
- `references/contribution-limits.md` — Current IRS limits for all account types
- `references/three-fund-portfolio.md` — Fund picks by brokerage, allocation rationale
- `references/planning-checklist.md` — Step-by-step financial planning checklist by life stage
- `references/professional-referral-guide.md` — When to seek professional financial guidance
