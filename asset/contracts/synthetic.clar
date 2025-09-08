;; Synthetic Asset Contract
;; A robust contract for creating and managing synthetic assets with collateral backing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_POSITION_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_LIQUIDATION_THRESHOLD (err u104))
(define-constant ERR_ORACLE_FAILURE (err u105))
(define-constant ERR_ASSET_NOT_FOUND (err u106))
;; Added new error constants for input validation
(define-constant ERR_INVALID_INPUT (err u107))
(define-constant ERR_EMPTY_STRING (err u108))

;; Minimum collateral ratio (150%)
(define-constant MIN_COLLATERAL_RATIO u150)
(define-constant LIQUIDATION_RATIO u120)
(define-constant PRECISION u100)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-synthetic-supply uint u0)
(define-data-var liquidation-penalty uint u10) ;; 10%

;; Data Maps
(define-map synthetic-assets 
  { asset-id: uint }
  { 
    name: (string-ascii 32),
    symbol: (string-ascii 10),
    price: uint,
    total-supply: uint,
    active: bool
  }
)

(define-map user-positions
  { user: principal, asset-id: uint }
  {
    collateral-amount: uint,
    synthetic-amount: uint,
    last-update: uint
  }
)

(define-map asset-balances
  { user: principal, asset-id: uint }
  { balance: uint }
)

(define-map authorized-oracles principal bool)
(define-map asset-counter uint uint)

;; Initialize asset counter
(map-set asset-counter u0 u0)

;; Read-only functions
(define-read-only (get-asset-info (asset-id uint))
  (map-get? synthetic-assets { asset-id: asset-id })
)

(define-read-only (get-user-position (user principal) (asset-id uint))
  (map-get? user-positions { user: user, asset-id: asset-id })
)

(define-read-only (get-balance (user principal) (asset-id uint))
  (default-to u0 (get balance (map-get? asset-balances { user: user, asset-id: asset-id })))
)

(define-read-only (calculate-collateral-ratio (collateral uint) (synthetic uint) (price uint))
  (if (is-eq synthetic u0)
    u0
    (/ (* collateral PRECISION) (* synthetic price))
  )
)

(define-read-only (is-position-liquidatable (user principal) (asset-id uint))
  (match (get-user-position user asset-id)
    position
    (match (get-asset-info asset-id)
      asset
      (let ((ratio (calculate-collateral-ratio 
                     (get collateral-amount position)
                     (get synthetic-amount position)
                     (get price asset))))
        (< ratio LIQUIDATION_RATIO))
      false)
    false)
)

(define-read-only (get-contract-stats)
  {
    total-supply: (var-get total-synthetic-supply),
    paused: (var-get contract-paused),
    liquidation-penalty: (var-get liquidation-penalty)
  }
)

;; Private functions
(define-private (is-authorized-oracle (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

(define-private (update-asset-balance (user principal) (asset-id uint) (amount uint))
  (map-set asset-balances 
    { user: user, asset-id: asset-id }
    { balance: amount }
  )
)

;; Added input validation helper functions
(define-private (is-valid-string (str (string-ascii 32)))
  (> (len str) u0)
)

(define-private (is-valid-symbol (str (string-ascii 10)))
  (> (len str) u0)
)

(define-private (is-valid-principal (addr principal))
  (not (is-eq addr 'SP000000000000000000002Q6VF78))
)

(define-private (asset-exists (asset-id uint))
  (is-some (map-get? synthetic-assets { asset-id: asset-id }))
)

;; Public functions
(define-public (create-synthetic-asset (name (string-ascii 32)) (symbol (string-ascii 10)) (initial-price uint))
  (let ((current-id (+ (default-to u0 (map-get? asset-counter u0)) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> initial-price u0) ERR_INVALID_AMOUNT)
    ;; Added input validation for name and symbol
    (asserts! (is-valid-string name) ERR_EMPTY_STRING)
    (asserts! (is-valid-symbol symbol) ERR_EMPTY_STRING)
    
    (map-set synthetic-assets
      { asset-id: current-id }
      {
        name: name,
        symbol: symbol,
        price: initial-price,
        total-supply: u0,
        active: true
      }
    )
    (map-set asset-counter u0 current-id)
    (ok current-id)
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Added input validation for oracle principal
    (asserts! (is-valid-principal oracle) ERR_INVALID_INPUT)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

(define-public (update-price (asset-id uint) (new-price uint))
  (begin
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
    ;; Added asset existence validation
    (asserts! (asset-exists asset-id) ERR_ASSET_NOT_FOUND)
    
    (match (get-asset-info asset-id)
      asset
      (begin
        (map-set synthetic-assets
          { asset-id: asset-id }
          (merge asset { price: new-price })
        )
        (ok true))
      ERR_ASSET_NOT_FOUND)
  )
)

(define-public (open-position (asset-id uint) (collateral-amount uint) (synthetic-amount uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (and (> collateral-amount u0) (> synthetic-amount u0)) ERR_INVALID_AMOUNT)
    ;; Added asset existence validation
    (asserts! (asset-exists asset-id) ERR_ASSET_NOT_FOUND)
    
    (let ((asset (unwrap! (get-asset-info asset-id) ERR_ASSET_NOT_FOUND)))
      (asserts! (get active asset) ERR_ASSET_NOT_FOUND)
      
      (let ((ratio (calculate-collateral-ratio collateral-amount synthetic-amount (get price asset))))
        (asserts! (>= ratio MIN_COLLATERAL_RATIO) ERR_INSUFFICIENT_COLLATERAL)
        
        ;; Transfer collateral (assuming STX as collateral)
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        ;; Update position
        (map-set user-positions
          { user: tx-sender, asset-id: asset-id }
          {
            collateral-amount: collateral-amount,
            synthetic-amount: synthetic-amount,
            last-update: block-height
          }
        )
        
        ;; Update balances
        (update-asset-balance tx-sender asset-id synthetic-amount)
        
        ;; Update total supply
        (map-set synthetic-assets
          { asset-id: asset-id }
          (merge asset { total-supply: (+ (get total-supply asset) synthetic-amount) })
        )
        (var-set total-synthetic-supply (+ (var-get total-synthetic-supply) synthetic-amount))
        
        (ok true)
      )
    )
  )
)

(define-public (close-position (asset-id uint))
  (begin
    ;; Added asset existence validation
    (asserts! (asset-exists asset-id) ERR_ASSET_NOT_FOUND)
    
    (let ((position (unwrap! (get-user-position tx-sender asset-id) ERR_POSITION_NOT_FOUND))
          (asset (unwrap! (get-asset-info asset-id) ERR_ASSET_NOT_FOUND)))
      
      ;; Return collateral
      (try! (as-contract (stx-transfer? (get collateral-amount position) tx-sender tx-sender)))
      
      ;; Update balances and supply
      (update-asset-balance tx-sender asset-id u0)
      (map-delete user-positions { user: tx-sender, asset-id: asset-id })
      
      (map-set synthetic-assets
        { asset-id: asset-id }
        (merge asset { total-supply: (- (get total-supply asset) (get synthetic-amount position)) })
      )
      (var-set total-synthetic-supply (- (var-get total-synthetic-supply) (get synthetic-amount position)))
      
      (ok true)
    )
  )
)

(define-public (liquidate-position (user principal) (asset-id uint))
  (begin
    ;; Added input validation for user and asset-id
    (asserts! (is-valid-principal user) ERR_INVALID_INPUT)
    (asserts! (asset-exists asset-id) ERR_ASSET_NOT_FOUND)
    
    (let ((position (unwrap! (get-user-position user asset-id) ERR_POSITION_NOT_FOUND))
          (asset (unwrap! (get-asset-info asset-id) ERR_ASSET_NOT_FOUND)))
      
      (asserts! (is-position-liquidatable user asset-id) ERR_LIQUIDATION_THRESHOLD)
      
      (let ((penalty-amount (/ (* (get collateral-amount position) (var-get liquidation-penalty)) u100))
            (remaining-collateral (- (get collateral-amount position) penalty-amount)))
        
        ;; Transfer penalty to liquidator
        (try! (as-contract (stx-transfer? penalty-amount tx-sender tx-sender)))
        
        ;; Return remaining collateral to user
        (try! (as-contract (stx-transfer? remaining-collateral tx-sender user)))
        
        ;; Clear position
        (map-delete user-positions { user: user, asset-id: asset-id })
        (update-asset-balance user asset-id u0)
        
        ;; Update supply
        (map-set synthetic-assets
          { asset-id: asset-id }
          (merge asset { total-supply: (- (get total-supply asset) (get synthetic-amount position)) })
        )
        (var-set total-synthetic-supply (- (var-get total-synthetic-supply) (get synthetic-amount position)))
        
        (ok true)
      )
    )
  )
)

(define-public (add-collateral (asset-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Added asset existence validation
    (asserts! (asset-exists asset-id) ERR_ASSET_NOT_FOUND)
    
    (let ((position (unwrap! (get-user-position tx-sender asset-id) ERR_POSITION_NOT_FOUND)))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      (map-set user-positions
        { user: tx-sender, asset-id: asset-id }
        (merge position { 
          collateral-amount: (+ (get collateral-amount position) amount),
          last-update: block-height
        })
      )
      (ok true)
    )
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (emergency-unpause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)
