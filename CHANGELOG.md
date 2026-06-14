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
