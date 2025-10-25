(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_PAPER_NOT_FOUND (err u404))
(define-constant ERR_PAPER_EXISTS (err u409))
(define-constant ERR_INVALID_AUTHOR (err u400))
(define-constant ERR_INVALID_PAPER (err u402))
(define-constant ERR_AUTHOR_EXISTS (err u403))
(define-constant ERR_NOT_PAPER_AUTHOR (err u405))
(define-constant ERR_PAPER_ALREADY_PUBLISHED (err u406))
(define-constant ERR_INSUFFICIENT_BALANCE (err u407))
(define-constant ERR_INVALID_REVIEW_STATE (err u410))
(define-constant ERR_INSUFFICIENT_REVIEWS (err u411))
(define-constant ERR_NO_PENDING_REWARDS (err u412))
(define-constant ERR_INSUFFICIENT_REWARD_POOL (err u413))

(define-constant SUBMISSION_FEE u1000000)
(define-constant PUBLICATION_FEE u5000000)
(define-constant BASE_REVIEW_REWARD u200000)
(define-constant QUALITY_BONUS_REWARD u100000)
(define-constant REJECTION_REFUND_AMOUNT u800000)
(define-constant MINIMUM_REVIEWS_REQUIRED u2)
(define-constant QUALITY_SCORE_THRESHOLD u8)

(define-data-var total-papers uint u0)
(define-data-var total-authors uint u0)
(define-data-var contract-balance uint u0)
(define-data-var total-reviewer-rewards-distributed uint u0)
(define-data-var pending-review-pool uint u0)

(define-map authors principal 
    {
        name: (string-ascii 100),
        institution: (string-ascii 200),
        email: (string-ascii 100),
        papers-count: uint,
        reputation-score: uint,
        joined-at: uint
    }
)

(define-map papers uint 
    {
        title: (string-ascii 200),
        abstract: (string-ascii 1000),
        authors: (list 10 principal),
        ipfs-hash: (string-ascii 100),
        keywords: (list 20 (string-ascii 50)),
        category: (string-ascii 50),
        submission-date: uint,
        publication-date: (optional uint),
        status: (string-ascii 20),
        peer-reviews: uint,
        citations: uint,
        access-fee: uint,
        submitter: principal
    }
)

(define-map reviewers principal
    {
        reputation-score: uint,
        reviews-completed: uint,
        total-reward-earned: uint,
        joined-at: uint
    }
)

(define-map paper-access uint (list 1000 principal))
(define-map author-papers principal (list 100 uint))
(define-map paper-citations uint (list 500 uint))
(define-map paper-reviews uint (list 50 {reviewer: principal, score: uint, comment: (string-ascii 500)}))
(define-map review-rewards-pending principal uint)
(define-map paper-review-count uint uint)

(define-public (register-author (name (string-ascii 100)) (institution (string-ascii 200)) (email (string-ascii 100)))
    (let
        (
            (author-exists (map-get? authors tx-sender))
        )
        (asserts! (is-none author-exists) ERR_AUTHOR_EXISTS)
        (map-set authors tx-sender 
            {
                name: name,
                institution: institution,
                email: email,
                papers-count: u0,
                reputation-score: u100,
                joined-at: stacks-block-height
            }
        )
        (var-set total-authors (+ (var-get total-authors) u1))
        (ok true)
    )
)

(define-public (submit-paper 
    (title (string-ascii 200))
    (abstract (string-ascii 1000))
    (paper-authors (list 10 principal))
    (ipfs-hash (string-ascii 100))
    (keywords (list 20 (string-ascii 50)))
    (category (string-ascii 50))
    (access-fee uint)
)
    (let
        (
            (paper-id (+ (var-get total-papers) u1))
            (current-balance (stx-get-balance tx-sender))
            (author-info (map-get? authors tx-sender))
        )
        (asserts! (is-some author-info) ERR_INVALID_AUTHOR)
        (asserts! (>= current-balance SUBMISSION_FEE) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> (len title) u0) ERR_INVALID_PAPER)
        (asserts! (> (len abstract) u0) ERR_INVALID_PAPER)
        (asserts! (> (len ipfs-hash) u0) ERR_INVALID_PAPER)
        
        (try! (stx-transfer? SUBMISSION_FEE tx-sender (as-contract tx-sender)))
        (var-set contract-balance (+ (var-get contract-balance) SUBMISSION_FEE))
        
        (map-set papers paper-id 
            {
                title: title,
                abstract: abstract,
                authors: paper-authors,
                ipfs-hash: ipfs-hash,
                keywords: keywords,
                category: category,
                submission-date: stacks-block-height,
                publication-date: none,
                status: "submitted",
                peer-reviews: u0,
                citations: u0,
                access-fee: access-fee,
                submitter: tx-sender
            }
        )
        
        (map-set author-papers tx-sender 
            (unwrap! 
                (as-max-len? 
                    (append 
                        (default-to (list) (map-get? author-papers tx-sender)) 
                        paper-id
                    ) 
                    u100
                ) 
                ERR_INVALID_PAPER
            )
        )
        
        (map-set authors tx-sender 
            (merge 
                (unwrap! author-info ERR_INVALID_AUTHOR)
                {papers-count: (+ (get papers-count (unwrap! author-info ERR_INVALID_AUTHOR)) u1)}
            )
        )
        
        (map-set paper-review-count paper-id u0)
        (var-set total-papers paper-id)
        (ok paper-id)
    )
)

(define-public (publish-paper (paper-id uint))
    (let
        (
            (paper (map-get? papers paper-id))
            (current-balance (stx-get-balance tx-sender))
        )
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-eq tx-sender (get submitter (unwrap! paper ERR_PAPER_NOT_FOUND))) ERR_NOT_PAPER_AUTHOR)
        (asserts! (is-eq (get status (unwrap! paper ERR_PAPER_NOT_FOUND)) "submitted") ERR_PAPER_ALREADY_PUBLISHED)
        (asserts! (>= current-balance PUBLICATION_FEE) ERR_INSUFFICIENT_BALANCE)
        
        (try! (stx-transfer? PUBLICATION_FEE tx-sender (as-contract tx-sender)))
        (var-set contract-balance (+ (var-get contract-balance) PUBLICATION_FEE))
        
        (map-set papers paper-id 
            (merge 
                (unwrap! paper ERR_PAPER_NOT_FOUND)
                {
                    status: "published",
                    publication-date: (some stacks-block-height)
                }
            )
        )
        (ok true)
    )
)

(define-public (begin-paper-review (paper-id uint))
    (let
        (
            (paper (map-get? papers paper-id))
        )
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-eq (get status (unwrap! paper ERR_PAPER_NOT_FOUND)) "submitted") ERR_INVALID_REVIEW_STATE)
        
        (map-set papers paper-id 
            (merge 
                (unwrap! paper ERR_PAPER_NOT_FOUND)
                {status: "under-review"}
            )
        )
        (ok true)
    )
)

(define-public (access-paper (paper-id uint))
    (let
        (
            (paper (map-get? papers paper-id))
            (access-fee (get access-fee (unwrap! paper ERR_PAPER_NOT_FOUND)))
            (current-balance (stx-get-balance tx-sender))
            (paper-submitter (get submitter (unwrap! paper ERR_PAPER_NOT_FOUND)))
        )
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-eq (get status (unwrap! paper ERR_PAPER_NOT_FOUND)) "published") ERR_PAPER_NOT_FOUND)
        (asserts! (>= current-balance access-fee) ERR_INSUFFICIENT_BALANCE)
        
        (if (> access-fee u0)
            (begin
                (try! (stx-transfer? access-fee tx-sender paper-submitter))
                (map-set paper-access paper-id 
                    (unwrap!
                        (as-max-len?
                            (append 
                                (default-to (list) (map-get? paper-access paper-id))
                                tx-sender
                            )
                            u1000
                        )
                        ERR_INVALID_PAPER
                    )
                )
            )
            true
        )
        (ok (get ipfs-hash (unwrap! paper ERR_PAPER_NOT_FOUND)))
    )
)

(define-public (cite-paper (citing-paper-id uint) (cited-paper-id uint))
    (let
        (
            (citing-paper (map-get? papers citing-paper-id))
            (cited-paper (map-get? papers cited-paper-id))
        )
        (asserts! (is-some citing-paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-some cited-paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-eq tx-sender (get submitter (unwrap! citing-paper ERR_PAPER_NOT_FOUND))) ERR_NOT_PAPER_AUTHOR)
        
        (map-set papers cited-paper-id 
            (merge 
                (unwrap! cited-paper ERR_PAPER_NOT_FOUND)
                {citations: (+ (get citations (unwrap! cited-paper ERR_PAPER_NOT_FOUND)) u1)}
            )
        )
        
        (map-set paper-citations cited-paper-id 
            (unwrap!
                (as-max-len?
                    (append 
                        (default-to (list) (map-get? paper-citations cited-paper-id))
                        citing-paper-id
                    )
                    u500
                )
                ERR_INVALID_PAPER
            )
        )
        (ok true)
    )
)

(define-public (finalize-review (paper-id uint))
    (let
        (
            (paper (map-get? papers paper-id))
            (review-count (default-to u0 (map-get? paper-review-count paper-id)))
        )
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-eq tx-sender (get submitter (unwrap! paper ERR_PAPER_NOT_FOUND))) ERR_NOT_PAPER_AUTHOR)
        (asserts! (is-eq (get status (unwrap! paper ERR_PAPER_NOT_FOUND)) "reviewed") ERR_INVALID_REVIEW_STATE)
        (asserts! (>= review-count MINIMUM_REVIEWS_REQUIRED) ERR_INSUFFICIENT_REVIEWS)
        
        (map-set papers paper-id 
            (merge 
                (unwrap! paper ERR_PAPER_NOT_FOUND)
                {
                    status: "published",
                    publication-date: (some stacks-block-height)
                }
            )
        )
        (ok true)
    )
)

(define-public (reject-paper (paper-id uint))
    (let
        (
            (paper (map-get? papers paper-id))
            (paper-submitter (get submitter (unwrap! paper ERR_PAPER_NOT_FOUND)))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (let
            (
                (paper-status (get status (unwrap! paper ERR_PAPER_NOT_FOUND)))
            )
            (asserts! (or (is-eq paper-status "under-review") (is-eq paper-status "reviewed")) ERR_INVALID_REVIEW_STATE)
        )
        
        (try! (stx-transfer? REJECTION_REFUND_AMOUNT (as-contract tx-sender) paper-submitter))
        (var-set contract-balance (- (var-get contract-balance) REJECTION_REFUND_AMOUNT))
        
        (map-set papers paper-id 
            (merge 
                (unwrap! paper ERR_PAPER_NOT_FOUND)
                {status: "rejected"}
            )
        )
        (ok true)
    )
)

(define-public (review-paper (paper-id uint) (score uint) (comment (string-ascii 500)))
    (let
        (
            (paper (map-get? papers paper-id))
            (reviewer-info (map-get? authors tx-sender))
            (current-review-count (default-to u0 (map-get? paper-review-count paper-id)))
            (reward-amount (if (>= score QUALITY_SCORE_THRESHOLD) (+ BASE_REVIEW_REWARD QUALITY_BONUS_REWARD) BASE_REVIEW_REWARD))
        )
        (asserts! (is-some paper) ERR_PAPER_NOT_FOUND)
        (asserts! (is-some reviewer-info) ERR_INVALID_AUTHOR)
        (asserts! (<= score u10) ERR_INVALID_PAPER)
        (asserts! (not (is-eq tx-sender (get submitter (unwrap! paper ERR_PAPER_NOT_FOUND)))) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status (unwrap! paper ERR_PAPER_NOT_FOUND)) "under-review") ERR_INVALID_REVIEW_STATE)
        
        (map-set paper-reviews paper-id 
            (unwrap!
                (as-max-len?
                    (append 
                        (default-to (list) (map-get? paper-reviews paper-id))
                        {reviewer: tx-sender, score: score, comment: comment}
                    )
                    u50
                )
                ERR_INVALID_PAPER
            )
        )
        
        (let
            (
                (existing-reviewer (map-get? reviewers tx-sender))
            )
            (if (is-some existing-reviewer)
                (map-set reviewers tx-sender
                    (merge
                        (unwrap! existing-reviewer ERR_INVALID_AUTHOR)
                        {
                            reviews-completed: (+ (get reviews-completed (unwrap! existing-reviewer ERR_INVALID_AUTHOR)) u1),
                            reputation-score: (+ (get reputation-score (unwrap! existing-reviewer ERR_INVALID_AUTHOR)) score),
                            total-reward-earned: (+ (get total-reward-earned (unwrap! existing-reviewer ERR_INVALID_AUTHOR)) reward-amount)
                        }
                    )
                )
                (map-set reviewers tx-sender
                    {
                        reputation-score: score,
                        reviews-completed: u1,
                        total-reward-earned: reward-amount,
                        joined-at: stacks-block-height
                    }
                )
            )
        )
        
        (map-set review-rewards-pending tx-sender
            (+ (default-to u0 (map-get? review-rewards-pending tx-sender)) reward-amount)
        )
        
        (var-set pending-review-pool (+ (var-get pending-review-pool) reward-amount))
        
        (let
            (
                (new-review-count (+ current-review-count u1))
            )
            (map-set paper-review-count paper-id new-review-count)
            
            (if (>= new-review-count MINIMUM_REVIEWS_REQUIRED)
                (map-set papers paper-id 
                    (merge 
                        (unwrap! paper ERR_PAPER_NOT_FOUND)
                        {status: "reviewed"}
                    )
                )
                true
            )
        )
        
        (map-set papers paper-id 
            (merge 
                (unwrap! paper ERR_PAPER_NOT_FOUND)
                {peer-reviews: (+ (get peer-reviews (unwrap! paper ERR_PAPER_NOT_FOUND)) u1)}
            )
        )
        (ok true)
    )
)

(define-public (claim-reviewer-rewards)
    (let
        (
            (pending-amount (default-to u0 (map-get? review-rewards-pending tx-sender)))
            (current-pool (var-get pending-review-pool))
        )
        (asserts! (> pending-amount u0) ERR_NO_PENDING_REWARDS)
        (asserts! (>= current-pool pending-amount) ERR_INSUFFICIENT_REWARD_POOL)
        
        (try! (stx-transfer? pending-amount (as-contract tx-sender) tx-sender))
        
        (map-delete review-rewards-pending tx-sender)
        (var-set pending-review-pool (- current-pool pending-amount))
        (var-set total-reviewer-rewards-distributed (+ (var-get total-reviewer-rewards-distributed) pending-amount))
        
        (ok pending-amount)
    )
)

(define-public (update-reputation (author principal) (points uint))
    (let
        (
            (author-info (map-get? authors author))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-some author-info) ERR_INVALID_AUTHOR)
        
        (map-set authors author 
            (merge 
                (unwrap! author-info ERR_INVALID_AUTHOR)
                {reputation-score: (+ (get reputation-score (unwrap! author-info ERR_INVALID_AUTHOR)) points)}
            )
        )
        (ok true)
    )
)

(define-read-only (get-paper (paper-id uint))
    (map-get? papers paper-id)
)

(define-read-only (get-author (author principal))
    (map-get? authors author)
)

(define-read-only (get-reviewer-info (reviewer principal))
    (map-get? reviewers reviewer)
)

(define-read-only (get-pending-reviewer-rewards (reviewer principal))
    (default-to u0 (map-get? review-rewards-pending reviewer))
)

(define-read-only (get-paper-review-status (paper-id uint))
    (match (map-get? papers paper-id)
        paper (ok (get status paper))
        (err ERR_PAPER_NOT_FOUND)
    )
)

(define-read-only (get-paper-reviews (paper-id uint))
    (map-get? paper-reviews paper-id)
)

(define-read-only (get-paper-citations (paper-id uint))
    (map-get? paper-citations paper-id)
)

(define-read-only (get-author-papers (author principal))
    (map-get? author-papers author)
)

(define-read-only (get-total-papers)
    (var-get total-papers)
)

(define-read-only (get-total-authors)
    (var-get total-authors)
)

(define-read-only (get-contract-stats)
    {
        total-papers: (var-get total-papers),
        total-authors: (var-get total-authors),
        contract-balance: (var-get contract-balance),
        total-reviewer-rewards-distributed: (var-get total-reviewer-rewards-distributed),
        pending-review-pool: (var-get pending-review-pool)
    }
)

(define-read-only (get-review-workflow-stats)
    {
        total-reviewer-rewards-distributed: (var-get total-reviewer-rewards-distributed),
        pending-review-pool: (var-get pending-review-pool),
        base-review-reward: BASE_REVIEW_REWARD,
        quality-bonus-reward: QUALITY_BONUS_REWARD,
        minimum-reviews-required: MINIMUM_REVIEWS_REQUIRED
    }
)

(define-read-only (has-paper-access (paper-id uint) (user principal))
    (is-some (index-of (default-to (list) (map-get? paper-access paper-id)) user))
)

(define-read-only (search-papers-by-category (category (string-ascii 50)))
    (ok "Use off-chain indexing for search functionality")
)

(define-read-only (get-paper-access-list (paper-id uint))
    (map-get? paper-access paper-id)
)

(define-read-only (get-paper-review-count (paper-id uint))
    (default-to u0 (map-get? paper-review-count paper-id))
)
