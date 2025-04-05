;; patient-anonymization.clar
;; Removes identifying information from patient records

(define-data-var admin principal tx-sender)

;; Data structure for anonymized patient records
(define-map anonymized-patients
  { patient-id: uint }
  {
    hash-id: (buff 32),
    age-range: (string-utf8 10),
    biological-sex: (string-utf8 1),
    region-code: (string-utf8 10),
    consent-level: uint
  }
)

;; Counter for generating unique patient IDs
(define-data-var patient-counter uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Generate a new patient ID
(define-private (generate-patient-id)
  (let ((current-id (var-get patient-counter)))
    (var-set patient-counter (+ current-id u1))
    current-id
  )
)

;; Add a new anonymized patient record
(define-public (add-anonymized-patient
    (hash-id (buff 32))
    (age-range (string-utf8 10))
    (biological-sex (string-utf8 1))
    (region-code (string-utf8 10))
    (consent-level uint))
  (let ((patient-id (generate-patient-id)))
    (map-set anonymized-patients
      { patient-id: patient-id }
      {
        hash-id: hash-id,
        age-range: age-range,
        biological-sex: biological-sex,
        region-code: region-code,
        consent-level: consent-level
      }
    )
    (ok patient-id)
  )
)

;; Get anonymized patient data
(define-read-only (get-anonymized-patient (patient-id uint))
  (map-get? anonymized-patients { patient-id: patient-id })
)

;; Update consent level
(define-public (update-consent-level (patient-id uint) (new-consent-level uint))
  (let ((patient-data (map-get? anonymized-patients { patient-id: patient-id })))
    (if (is-some patient-data)
      (begin
        (map-set anonymized-patients
          { patient-id: patient-id }
          (merge (unwrap-panic patient-data) { consent-level: new-consent-level })
        )
        (ok true)
      )
      (err u1) ;; Patient not found
    )
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
