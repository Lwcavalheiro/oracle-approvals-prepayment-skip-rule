# Oracle ERP Fusion – Invoice Approval: Skip Rule for Prepayment Vendors

## 📋 Overview

This project documents a **BPM Workflow customization** in **Oracle ERP Fusion Payables** that automatically inserts a dedicated approver into the invoice approval flow whenever a **Standard invoice** is submitted for a vendor that has an **open prepayment (adiantamento)**.

The approver is injected via a **Skip Rule** on a parallel participant: when no open prepayment exists, the participant is skipped and the invoice flows normally. When an open prepayment is detected, the participant is activated — blocking approval until that designated approver explicitly reviews and approves the invoice.

---

## 🎯 Business Case

When a company pays a vendor in advance (**prepayment / adiantamento**), that balance must be applied to a future Standard invoice before payment is released. Without a control in place, a Standard invoice could be approved and paid without anyone noticing the open prepayment — resulting in the vendor being paid twice for the same amount.

This customization solves this by injecting a mandatory approver into the workflow:

- When a **Standard invoice** enters the approval flow, the workflow queries whether the **vendor has any paid, available, non-cancelled prepayment**.
- If **yes** → a dedicated approver is **activated** in the parallel step. The invoice **cannot be fully approved** without their explicit action.
- If **no** → that parallel participant is **skipped** and the invoice flows through the normal approval path without interruption.

This ensures that no Standard invoice for a vendor with an open prepayment slips through without a responsible reviewer being notified.

---

## 🔧 Module & Technology

| Component | Detail |
|---|---|
| **ERP System** | Oracle ERP Cloud (Fusion) |
| **Module** | Payables (AP) |
| **Feature** | Invoice Approval Workflow (BPM Worklist) |
| **Participant Type** | Parallel Participant |
| **Rule Type** | Skip Rule |
| **Expression Language** | XPath / ORCL Functions |
| **Data Source** | `jdbc/ApplicationDBDS` |

---

## 🗂️ Project Structure

```
oracle-approvals-prepayment-skip-rule/
│
├── README.md                         # This file
│
├── workflow/
│   └── skip-rule-expression.txt      # The BPM skip rule expression
│
├── sql/
│   └── prepayment_check_query.sql    # Underlying SQL query (for reference/testing)
│
└── docs/
    └── setup-guide.md                # Step-by-step configuration guide
```

---

## ⚙️ Skip Rule Expression

The following expression is applied to the parallel participant `SoaOLabel.InvoiceApproversParallelParticipantinPar`:

```xpath
orcl:query-database(
  concat(
    'SELECT COUNT(AD.INVOICE_ID) TOTAL
     FROM AP_INVOICES_ALL AIA, AP_INVOICES_ALL AD
     WHERE 1=1
       AND AIA.VENDOR_SITE_ID = AD.VENDOR_SITE_ID
       AND AD.INVOICE_TYPE_LOOKUP_CODE = ''PREPAYMENT''
       AND AD.PAYMENT_STATUS_FLAG = ''Y''
       AND AD.APPROVAL_STATUS = ''AVAILABLE''
       AND AD.CANCELLED_DATE IS NULL
       AND AIA.INVOICE_ID = ',
    /task:task/task:identificationKey
  ),
  true(),
  true(),
  'jdbc/ApplicationDBDS'
) = 0
```

### Logic Explanation

| Condition | Result |
|---|---|
| Query returns `0` (no open prepayments) | Expression = `true` → **Skip the approver** |
| Query returns `> 0` (open prepayment exists) | Expression = `false` → **Keep the approver active** |

### SQL Filter Breakdown

| Filter | Description |
|---|---|
| `INVOICE_TYPE_LOOKUP_CODE = 'PREPAYMENT'` | Only considers prepayment invoices |
| `PAYMENT_STATUS_FLAG = 'Y'` | Prepayment has been paid |
| `APPROVAL_STATUS = 'AVAILABLE'` | Prepayment balance is still available to be applied |
| `CANCELLED_DATE IS NULL` | Prepayment has not been cancelled |
| `AIA.VENDOR_SITE_ID = AD.VENDOR_SITE_ID` | Matches the vendor site of the current invoice being approved |
| `AIA.INVOICE_ID = identificationKey` | Scopes the lookup to the current invoice in the workflow |

---

## 🖼️ Workflow Diagram

The approval workflow consists of:

1. **Initial parallel group** — Routes to `Invoice Document...`, `SoaOLabel.Invo...` participants simultaneously.
2. **Sequential step** — `Invoice Document...` (edit task).
3. **Invoice Request step** — `Invoice Reques...`.
4. **Final parallel group** — Routes to three participants simultaneously:
   - `Invoice Docume...` (top)
   - `Invoice Docume...` (middle) ← **This participant has the prepayment Skip Rule applied**
   - `Invoice Docume...` (bottom)
5. **End state** — Approval complete.

> See `screenshots/` for the BPM Worklist configuration screenshot.

---

## 🚀 Setup Guide

See [`docs/setup-guide.md`](docs/setup-guide.md) for the full step-by-step configuration.

---

## ⚠️ Important Notes

- The `identificationKey` in the XPath expression refers to the **Invoice ID** passed by the workflow context at runtime.
- The `jdbc/ApplicationDBDS` datasource is Oracle Fusion's standard JDBC datasource — no custom datasource configuration is needed.
- Test the SQL query in your environment before deploying to production (see [`sql/prepayment_check_query.sql`](sql/prepayment_check_query.sql)).
- Changes to BPM task configurations require **SOA/BPM deployment** and may need approval from your Oracle Cloud administrator.

---

## 📄 License

Internal use. Adapt freely for your Oracle ERP Fusion environment.
