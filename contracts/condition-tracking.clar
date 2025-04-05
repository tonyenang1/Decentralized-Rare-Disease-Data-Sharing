;; condition-tracking.clar
;; Records symptoms and progression patterns

(define-data-var admin principal tx-sender)

;; Data structure for conditions
(define-map conditions
  { condition-id: uint }
  {
    name: (string-utf8 100),
    category: (string-utf8 50),
    is-rare: bool
  }
)

;; Data structure for symptoms
(define-map symptoms
  { symptom-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500)
  }
)

;; Mapping conditions to symptoms
(define-map condition-symptoms
  { condition-id: uint, symptom-id: uint }
  { severity-scale: uint }
)

;; Patient condition records
(define-map patient-conditions
  { patient-id: uint, condition-id: uint }
  {
    diagnosis-timestamp: uint,
    progression-stage: uint,
    last-updated: uint
  }
)

;; Patient symptom records
(define-map patient-symptoms
  { patient-id: uint, symptom-id: uint }
  {
    severity: uint,
    onset-timestamp: uint,
    last-updated: uint
  }
)

;; Counters
(define-data-var condition-counter uint u0)
(define-data-var symptom-counter uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Add a new condition
(define-public (add-condition
    (name (string-utf8 100))
    (category (string-utf8 50))
    (is-rare bool))
  (begin
    (asserts! (is-admin) (err u403))
    (let ((condition-id (var-get condition-counter)))
      (var-set condition-counter (+ condition-id u1))
      (map-set conditions
        { condition-id: condition-id }
        {
          name: name,
          category: category,
          is-rare: is-rare
        }
      )
      (ok condition-id)
    )
  )
)

;; Add a new symptom
(define-public (add-symptom
    (name (string-utf8 100))
    (description (string-utf8 500)))
  (begin
    (asserts! (is-admin) (err u403))
    (let ((symptom-id (var-get symptom-counter)))
      (var-set symptom-counter (+ symptom-id u1))
      (map-set symptoms
        { symptom-id: symptom-id }
        {
          name: name,
          description: description
        }
      )
      (ok symptom-id)
    )
  )
)

;; Associate symptom with condition
(define-public (link-symptom-to-condition
    (condition-id uint)
    (symptom-id uint)
    (severity-scale uint))
  (begin
    (asserts! (is-admin) (err u403))
    (map-set condition-symptoms
      { condition-id: condition-id, symptom-id: symptom-id }
      { severity-scale: severity-scale }
    )
    (ok true)
  )
)

;; Record patient condition
(define-public (record-patient-condition
    (patient-id uint)
    (condition-id uint)
    (progression-stage uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    (map-set patient-conditions
      { patient-id: patient-id, condition-id: condition-id }
      {
        diagnosis-timestamp: current-time,
        progression-stage: progression-stage,
        last-updated: current-time
      }
    )
    (ok true)
  )
)

;; Record patient symptom
(define-public (record-patient-symptom
    (patient-id uint)
    (symptom-id uint)
    (severity uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    (map-set patient-symptoms
      { patient-id: patient-id, symptom-id: symptom-id }
      {
        severity: severity,
        onset-timestamp: current-time,
        last-updated: current-time
      }
    )
    (ok true)
  )
)

;; Update patient condition progression
(define-public (update-condition-progression
    (patient-id uint)
    (condition-id uint)
    (new-progression-stage uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (condition-data (map-get? patient-conditions { patient-id: patient-id, condition-id: condition-id }))
  )
    (if (is-some condition-data)
      (begin
        (map-set patient-conditions
          { patient-id: patient-id, condition-id: condition-id }
          (merge (unwrap-panic condition-data)
            {
              progression-stage: new-progression-stage,
              last-updated: current-time
            }
          )
        )
        (ok true)
      )
      (err u1) ;; Record not found
    )
  )
)

;; Get condition details
(define-read-only (get-condition (condition-id uint))
  (map-get? conditions { condition-id: condition-id })
)

;; Get symptom details
(define-read-only (get-symptom (symptom-id uint))
  (map-get? symptoms { symptom-id: symptom-id })
)

;; Get patient condition
(define-read-only (get-patient-condition (patient-id uint) (condition-id uint))
  (map-get? patient-conditions { patient-id: patient-id, condition-id: condition-id })
)

;; Get patient symptom
(define-read-only (get-patient-symptom (patient-id uint) (symptom-id uint))
  (map-get? patient-symptoms { patient-id: patient-id, symptom-id: symptom-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
