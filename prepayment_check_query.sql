-- =============================================================================
-- FILE: prepayment_check_query.sql
-- PURPOSE: Reference query used inside the BPM Skip Rule expression.
--          Use this to test/validate results before deploying to the workflow.
-- MODULE:  Oracle ERP Fusion Payables – AP_INVOICES_ALL
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. CORE QUERY (mirrors exactly what the Skip Rule executes at runtime)
--    Replace :INVOICE_ID with a real invoice ID to test.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT COUNT(AD.INVOICE_ID) AS TOTAL
FROM   AP_INVOICES_ALL AIA
      ,AP_INVOICES_ALL AD
WHERE  1=1
  AND  AIA.VENDOR_SITE_ID          = AD.VENDOR_SITE_ID
  AND  AD.INVOICE_TYPE_LOOKUP_CODE = 'PREPAYMENT'
  AND  AD.PAYMENT_STATUS_FLAG      = 'Y'
  AND  AD.APPROVAL_STATUS          = 'AVAILABLE'
  AND  AD.CANCELLED_DATE           IS NULL
  AND  AIA.INVOICE_ID              = :INVOICE_ID   -- runtime: /task:task/task:identificationKey
;

-- Expected results:
--   TOTAL = 0  → No open prepayment → approver will be SKIPPED
--   TOTAL > 0  → Open prepayment exists → approver will be ACTIVATED


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. DIAGNOSTIC QUERY – Full prepayment detail for a given invoice
--    Useful during testing to inspect which prepayments are triggering the rule.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    AIA.INVOICE_ID                          AS CURRENT_INVOICE_ID
   ,AIA.INVOICE_NUM                         AS CURRENT_INVOICE_NUM
   ,AIA.INVOICE_DATE                        AS CURRENT_INVOICE_DATE
   ,AIA.VENDOR_ID                           AS VENDOR_ID
   ,AIA.VENDOR_SITE_ID                      AS VENDOR_SITE_ID
   -- Prepayment details
   ,AD.INVOICE_ID                           AS PREPAYMENT_ID
   ,AD.INVOICE_NUM                          AS PREPAYMENT_NUM
   ,AD.INVOICE_DATE                         AS PREPAYMENT_DATE
   ,AD.INVOICE_AMOUNT                       AS PREPAYMENT_AMOUNT
   ,AD.AMOUNT_PAID                          AS PREPAYMENT_AMOUNT_PAID
   ,AD.APPROVAL_STATUS                      AS PREPAYMENT_APPROVAL_STATUS
   ,AD.PAYMENT_STATUS_FLAG                  AS PREPAYMENT_PAYMENT_STATUS
   ,AD.CANCELLED_DATE                       AS PREPAYMENT_CANCELLED_DATE
FROM
    AP_INVOICES_ALL AIA
   ,AP_INVOICES_ALL AD
WHERE  1=1
  AND  AIA.VENDOR_SITE_ID          = AD.VENDOR_SITE_ID
  AND  AD.INVOICE_TYPE_LOOKUP_CODE = 'PREPAYMENT'
  AND  AD.PAYMENT_STATUS_FLAG      = 'Y'
  AND  AD.APPROVAL_STATUS          = 'AVAILABLE'
  AND  AD.CANCELLED_DATE           IS NULL
  AND  AIA.INVOICE_ID              = :INVOICE_ID
ORDER BY
    AD.INVOICE_DATE DESC
;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. BULK CHECK – List all invoices currently pending workflow approval
--    that have at least one open prepayment for the same vendor site.
--    Useful for auditing before enabling the rule in production.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    AIA.INVOICE_ID
   ,AIA.INVOICE_NUM
   ,AIA.INVOICE_DATE
   ,AIA.INVOICE_AMOUNT
   ,AIA.APPROVAL_STATUS          AS INVOICE_APPROVAL_STATUS
   ,AIA.VENDOR_ID
   ,AIA.VENDOR_SITE_ID
   ,COUNT(AD.INVOICE_ID)         AS OPEN_PREPAYMENTS
FROM
    AP_INVOICES_ALL AIA
JOIN AP_INVOICES_ALL AD
    ON  AD.VENDOR_SITE_ID          = AIA.VENDOR_SITE_ID
    AND AD.INVOICE_TYPE_LOOKUP_CODE = 'PREPAYMENT'
    AND AD.PAYMENT_STATUS_FLAG      = 'Y'
    AND AD.APPROVAL_STATUS          = 'AVAILABLE'
    AND AD.CANCELLED_DATE           IS NULL
WHERE
    AIA.INVOICE_TYPE_LOOKUP_CODE <> 'PREPAYMENT'           -- exclude prepayments themselves
    AND AIA.APPROVAL_STATUS IN ('REQUIRED', 'INITIATED')   -- only invoices in approval flow
GROUP BY
    AIA.INVOICE_ID
   ,AIA.INVOICE_NUM
   ,AIA.INVOICE_DATE
   ,AIA.INVOICE_AMOUNT
   ,AIA.APPROVAL_STATUS
   ,AIA.VENDOR_ID
   ,AIA.VENDOR_SITE_ID
HAVING COUNT(AD.INVOICE_ID) > 0
ORDER BY
    AIA.INVOICE_DATE DESC
;


-- ─────────────────────────────────────────────────────────────────────────────
-- COLUMN REFERENCE – AP_INVOICES_ALL (relevant fields)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- INVOICE_ID                : Unique invoice identifier (PK)
-- INVOICE_TYPE_LOOKUP_CODE  : 'STANDARD', 'PREPAYMENT', 'CREDIT', 'DEBIT MEMO', etc.
-- PAYMENT_STATUS_FLAG       : 'Y' = fully paid, 'P' = partially paid, 'N' = not paid
-- APPROVAL_STATUS           : 'AVAILABLE' = balance available to apply to invoices
--                             'UNAPPROVED', 'APPROVED', 'CANCELLED', etc.
-- CANCELLED_DATE            : NULL = not cancelled; populated = cancelled
-- VENDOR_SITE_ID            : Foreign key to AP_SUPPLIER_SITES_ALL
-- =============================================================================
