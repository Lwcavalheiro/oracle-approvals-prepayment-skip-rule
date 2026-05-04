# Setup Guide – Invoice Approval Skip Rule for Prepayment Vendors

## Prerequisites

- Access to **Oracle ERP Fusion** with Payables Administrator or System Administrator role.
- Access to **BPM Worklist** (Human Workflow) configuration.
- The invoice approval task must already be deployed and active.
- Familiarity with Oracle BPM / SOA Suite task configuration.

---

## Step 1 – Open the Invoice Approval Task

1. Navigate to **Setup and Maintenance** → **Financials** → **Payables**.
2. Search for the task: **Manage Invoice Approval Rules** or open the workflow directly via BPM Worklist.
3. In BPM Worklist, go to **Administration** → **Task Configuration**.
4. Search for the **InvoiceApproval** task and open it.
5. Navigate to the **Assignees** tab.

---

## Step 2 – Identify the Target Parallel Participant

In the **Assignees** workflow diagram, locate the parallel group that contains the approver you want to conditionally activate.

Based on this project, the target participant is:

```
SoaOLabel.InvoiceApproversParallelParticipantinPar
```

Click on this participant to select it. The configuration panel will appear at the bottom of the screen.

---

## Step 3 – Configure the Skip Rule

1. In the participant configuration panel, click the **Advanced** tab.
2. Check the box: **☑ Specify skip rule**.
3. In the text field that appears, paste the following expression:

```
orcl:query-database(concat('SELECT COUNT(AD.INVOICE_ID) TOTAL FROM AP_INVOICES_ALL AIA,AP_INVOICES_ALL AD WHERE 1=1 AND AIA.VENDOR_SITE_ID = AD.VENDOR_SITE_ID AND AD.INVOICE_TYPE_LOOKUP_CODE = ''PREPAYMENT'' AND AD.PAYMENT_STATUS_FLAG = ''Y'' AND AD.APPROVAL_STATUS = ''AVAILABLE'' AND AD.CANCELLED_DATE IS NULL AND AIA.INVOICE_ID=',/task:task/task:identificationKey), true(), true(),'jdbc/ApplicationDBDS')=0
```

4. Click the **expression builder icon** (pencil/formula icon) next to the field to validate the XPath syntax.

> ⚠️ **Note on quotes:** Inside the `concat()` SQL string, Oracle SQL single quotes are escaped by doubling them (`''`). This is correct and expected — do not change them to single quotes.

---

## Step 4 – Save and Deploy

1. Click **Save** on the task configuration.
2. If required by your environment, click **Commit** or **Deploy** to push changes to the SOA server.
3. In some environments, changes require a **SOA composite redeployment** — coordinate with your Oracle Cloud or middleware administrator.

---

## Step 5 – Test the Configuration

### Manual Test via SQL

Before submitting invoices through the workflow, test the SQL query directly in your Oracle environment:

1. Open a SQL client with access to Fusion schema (e.g., OTBI, SQL Developer with Fusion DB access, or a custom JDBC query tool).
2. Open [`../sql/prepayment_check_query.sql`](../sql/prepayment_check_query.sql).
3. Run **Query 1** with a known `INVOICE_ID` for a vendor that has an open prepayment.
4. Verify the count returned is `> 0`.
5. Run again with an `INVOICE_ID` for a vendor with **no** open prepayment and verify count = `0`.

### Workflow Test

1. Submit a test invoice for a vendor that has an **open prepayment** marked `AVAILABLE`.
2. Verify the workflow routes to the parallel participant (approver is **not** skipped).
3. Submit a test invoice for a vendor with **no open prepayments**.
4. Verify the parallel participant is **skipped** and the invoice moves to the next step.

---

## Troubleshooting

| Symptom | Possible Cause | Solution |
|---|---|---|
| Approver always skipped | SQL always returns 0 | Check `APPROVAL_STATUS` — value might be `'USED'` or `'UNAPPROVED'` instead of `'AVAILABLE'` |
| Approver never skipped | Expression syntax error | Open expression builder and check for XPath validation errors |
| Expression field grayed out | Missing role/permission | Ensure you have BPM Admin role in Fusion |
| Error: cannot connect to datasource | JNDI name mismatch | Verify `jdbc/ApplicationDBDS` is the correct name in your environment |
| `identificationKey` returns null | Workflow context mismatch | Confirm the task payload contains `identificationKey` mapped to INVOICE_ID |

---

## Related Documentation

- [Oracle Docs: Human Workflow Skip Rules](https://docs.oracle.com/en/middleware/fusion-middleware/soasuite/develop/creating-human-workflow-task-definitions.html)
- [Oracle Docs: AP_INVOICES_ALL Table Reference](https://docs.oracle.com/en/cloud/saas/financials/24d/oedmf/apinvoicesall-5961.html)
- [ORCL XPath Functions: orcl:query-database](https://docs.oracle.com/middleware/12212/soasuite/develop/XPREF/lot-xpathfn.htm)
