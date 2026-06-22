# 1.2.0

* Added support for tax identification number for non PL entites via `taxIdType` field

# 1.1.1

* bugfix: currency rate location in xml

# 1.1.0

* Added simple `NbpClient` to fetch NBP exchange rates for foreign-currency invoices

# 1.0.0

* **breaking change:** Monetary amounts now use `int` in minor currency units (grosz for PLN,
  cent for EUR) instead of `double` to avoid floating-point precision errors.
  Multiply existing values by 100 to migrate (e.g. `unitNetPrice: 100.00` → `unitNetPrice: 10000`).

# 0.3.0

* added `buildVerificationUrl` `validateKsefNumber` `buildKsefNumber` `testToken` helpers
* removed `validateTotals` and renamed `totals` to `forceTotals` to favor users own validation
* handle optional nip (personal invoices)
* allow manual set of creation date
* fix totals calculation for legacy tax classes and added all supported exceptions
* fix generated xml fields order

# 0.2.0

* added invoice XML generation and `sendInvoice` method

# 0.1.0

* initial release
