;; research-access.clar
;; Manages permissions for scientific study

(define-data-var admin principal tx-sender)

;; Data structure for research institutions
(define-map research-institutions
  { institution-id: uint }
  {
    name: (string-utf8 100),
    principal: principal,
    verification-level: uint,
    active: bool
  }
)

;; Data structure for research studies
(define-map research-studies
  { study-id: uint }
  {
    institution-id: uint,
    title: (string-utf8 200),
    description: (string-utf8 500),
    required-consent-level: uint,
    start-date: uint,
    end-date: uint,
    active: bool
  }
)

;; Data structure for data access grants
(define-map data-access-grants
  { study-id: uint, data-type: (string-utf8 50) }
  {
    access-level: uint,
    granted-at: uint,
    expires-at: uint,
    revocable: bool
  }
)

;; Patient consent for specific studies
(define-map patient-study-consent
  { patient-id: uint, study-id: uint }
  {
    consent-given: bool,
    consent-timestamp: uint,
    consent-expiration: uint
  }
)

;; Counters
(define-data-var institution-counter uint u0)
(define-data-var study-counter uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if caller is the registered institution
(define-private (is-institution (institution-id uint))
  (let ((institution (map-get? research-institutions { institution-id: institution-id })))
    (and
      (is-some institution)
      (is-eq tx-sender (get principal (unwrap-panic institution)))
    )
  )
)

;; Register a new research institution
(define-public (register-institution
    (name (string-utf8 100))
    (institution-principal principal)
    (verification-level uint))
  (begin
    (asserts! (is-admin) (err u403))
    (let ((institution-id (var-get institution-counter)))
      (var-set institution-counter (+ institution-id u1))
      (map-set research-institutions
        { institution-id: institution-id }
        {
          name: name,
          principal: institution-principal,
          verification-level: verification-level,
          active: true
        }
      )
      (ok institution-id)
    )
  )
)

;; Register a new research study
(define-public (register-study
    (institution-id uint)
    (title (string-utf8 200))
    (description (string-utf8 500))
    (required-consent-level uint)
    (start-date uint)
    (end-date uint))
  (begin
    (asserts! (is-institution institution-id) (err u403))
    (let ((study-id (var-get study-counter)))
      (var-set study-counter (+ study-id u1))
      (map-set research-studies
        { study-id: study-id }
        {
          institution-id: institution-id,
          title: title,
          description: description,
          required-consent-level: required-consent-level,
          start-date: start-date,
          end-date: end-date,
          active: true
        }
      )
      (ok study-id)
    )
  )
)

;; Grant data access for a study
(define-public (grant-data-access
    (study-id uint)
    (data-type (string-utf8 50))
    (access-level uint)
    (duration uint))
  (begin
    (asserts! (is-admin) (err u403))
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expiration (+ current-time duration))
    )
      (map-set data-access-grants
        { study-id: study-id, data-type: data-type }
        {
          access-level: access-level,
          granted-at: current-time,
          expires-at: expiration,
          revocable: true
        }
      )
      (ok true)
    )
  )
)

;; Record patient consent for a study
(define-public (record-patient-consent
    (patient-id uint)
    (study-id uint)
    (consent-given bool)
    (consent-duration uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (expiration (+ current-time consent-duration))
  )
    (map-set patient-study-consent
      { patient-id: patient-id, study-id: study-id }
      {
        consent-given: consent-given,
        consent-timestamp: current-time,
        consent-expiration: expiration
      }
    )
    (ok true)
  )
)

;; Check if a study has access to a patient's data
(define-read-only (check-study-access (study-id uint) (patient-id uint) (data-type (string-utf8 50)))
  (let (
    (study (map-get? research-studies { study-id: study-id }))
    (consent (map-get? patient-study-consent { patient-id: patient-id, study-id: study-id }))
    (access-grant (map-get? data-access-grants { study-id: study-id, data-type: data-type }))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (if (and
          (is-some study)
          (get active (unwrap-panic study))
          (is-some consent)
          (get consent-given (unwrap-panic consent))
          (< current-time (get consent-expiration (unwrap-panic consent)))
          (is-some access-grant)
          (< current-time (get expires-at (unwrap-panic access-grant)))
        )
      (ok true)
      (ok false)
    )
  )
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? research-institutions { institution-id: institution-id })
)

;; Get study details
(define-read-only (get-study (study-id uint))
  (map-get? research-studies { study-id: study-id })
)

;; Revoke data access
(define-public (revoke-data-access (study-id uint) (data-type (string-utf8 50)))
  (begin
    (asserts! (is-admin) (err u403))
    (let ((access-grant (map-get? data-access-grants { study-id: study-id, data-type: data-type })))
      (if (and (is-some access-grant) (get revocable (unwrap-panic access-grant)))
        (begin
          (map-delete data-access-grants { study-id: study-id, data-type: data-type })
          (ok true)
        )
        (err u1)
      )
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
