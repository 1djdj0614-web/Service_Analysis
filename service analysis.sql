-- ============================================================
-- 프로젝트: 코스메틱 이커머스 AARRR 퍼널 분석
-- 데이터: ecommerce-events-history-in-cosmetics-shop (Kaggle)
-- 분석 기간: 2019년 11월 ~ 12월
-- ============================================================


---- STEP 1. 데이터 탐색
-- -- 11월, 12월 데이터 합치기
-- CREATE OR REPLACE TABLE `service-492103.beauty.events_combined` AS
-- SELECT *, '2019-11' AS month FROM `service-492103.beauty.nov`
-- UNION ALL
-- SELECT *, '2019-12' AS month FROM `service-492103.beauty.dec`;

---- 기본 구조 확인
-- SELECT *
-- FROM `service-492103.beauty.events_combined` LIMIT 5

---- 이벤트 종류 확인
-- SELECT 
--   event_type,
--   COUNT(*) as cnt
-- FROM `service-492103.beauty.events_combined`
-- GROUP BY event_type
-- ORDER BY cnt DESC

---- 기간 및 유저 수 확인
-- SELECT 
--   MIN(event_time) as start_date,
--   MAX(event_time) as end_date,
--   COUNT(DISTINCT user_id) as unique_users
-- FROM `service-492103.beauty.events_combined`


-- AARRR 단계 선택
-- Activation 
-- view → cart → purchase 흐름이 명확하다.
-- 위 흐름에서 이탈 구간을 파악하고 싶다.
-- remove_from_cart로 장바구니 이탈 분석까지 가능하다.

---- 지표 기준
---- [지표 기준 정의]
---- view : 기간 내 상품을 1회 이상 조회한 유저 (user_id 기준)
---- cart : 기간 내 장바구니에 1회 이상 담은 유저 (user_id 기준)
---- purchase : 기간 내 실제 구매한 유저 (user_id 기준)
---- 이탈: 다음 단계 이벤트가 없는 유저
---- 분석 단위: 유저 기준 (중복 제외)


---- STEP 2. 데이터 전처리
---- 결측치 확인
-- SELECT
--   COUNTIF(event_time IS NULL) AS null_event_time,
--   COUNTIF(event_type IS NULL) AS null_event_type,
--   COUNTIF(product_id IS NULL) AS null_product_id,
--   COUNTIF(category_code IS NULL) AS null_category_code,
--   COUNTIF(brand IS NULL) AS null_brand,
--   COUNTIF(price IS NULL) AS null_price,
--   COUNTIF(user_id IS NULL) AS null_user_id,
--   COUNTIF(user_session IS NULL) AS null_user_session
-- FROM `service-492103.beauty.events_combined`

---- 이상치 확인
-- SELECT
--   MIN(price) AS min_price,
--   MAX(price) AS max_price,
--   AVG(price) AS avg_price,
--   COUNTIF(price = 0) AS zero_price_cnt,
--   COUNTIF(price < 0) AS negative_price_cnt
-- FROM `service-492103.beauty.events_combined`

---- 중복 확인
-- SELECT COUNT(*) AS distinct_rows
-- FROM (
--   SELECT DISTINCT event_time, user_id, product_id
--   FROM `service-492103.beauty.events_combined`
-- )


---- 클린 테이블
-- CREATE OR REPLACE TABLE `service-492103.beauty.events_clean` AS
-- SELECT DISTINCT
--   event_time,
--   event_type,
--   product_id,
--   category_id,
--   category_code,
--   brand,
--   price,
--   user_id,
--   user_session,
--   month
-- FROM `service-492103.beauty.events_combined`
-- WHERE user_session IS NOT NULL
--   AND price > 0

---- 클린 테이블 확인
-- SELECT
--   COUNT(*) AS total_rows,
--   COUNT(DISTINCT user_id) AS unique_users
-- FROM `service-492103.beauty.events_clean`


---- STEP 3. 퍼널 분석
---- 전체 퍼널 분석: 단계별 유저 수와 전환율
-- SELECT
--   view_users,
--   cart_users,
--   purchase_users,
--   ROUND(cart_users / view_users * 100, 1) AS view_to_cart_rate,
--   ROUND(purchase_users / cart_users * 100, 1) AS cart_to_purchase_rate,
--   ROUND(purchase_users / view_users * 100, 1) AS total_conversion_rate
-- FROM (
--   SELECT
--     COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_id END) AS view_users,
--     COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_id END) AS cart_users,
--     COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users
--   FROM `service-492103.beauty.events_clean`
-- )

---- 결과: view 660,373 / cart 160,523 / purchase 52,798
---- view→cart 24.3% / cart→purchase 32.9% / 전체 전환율 8.0%
---- → 최대 이탈: view→cart 구간 (75.7%)


---- 월별 퍼널: 유저 수와 전환율(11월과 12월)
-- SELECT
--   month,
--   view_users,
--   cart_users,
--   purchase_users,
--   ROUND(cart_users / view_users * 100, 1) AS view_to_cart_rate,
--   ROUND(purchase_users / cart_users * 100, 1) AS cart_to_purchase_rate,
--   ROUND(purchase_users / view_users * 100, 1) AS total_conversion_rate
-- FROM (
--   SELECT
--     month,
--     COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_id END) AS view_users,
--     COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_id END) AS cart_users,
--     COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users
--   FROM `service-492103.beauty.events_clean`
--   GROUP BY month
-- )
-- ORDER BY month

----결과
---- month	  view_users	cart_users	purchase_users	  view_to_cart_rate	  cart_to_purchase_rate 	total_conversion_rate
---- 2019-11	355424	    95778	      31524	            26.9	              32.9	                  8.9
---- 2019-12	357797	    83288	      25613	            23.3	              30.8	                  7.2
---- view 유저수는 11월, 12월 거의 동일하지만 view to cartsms 3.6% 감소, cart to purchase는 2.1%, 전체 1.7% 감소


---- remove_from_cart 분석: 장바구니 행동분석
-- SELECT
--   behavior_type,
--   user_count,
--   ROUND(user_count / SUM(user_count) OVER () * 100, 1) AS rate
-- FROM (
--   SELECT
--     CASE
--       WHEN did_cart = 1 AND did_remove = 1 AND did_purchase = 1 THEN 'removed_purchased'
--       WHEN did_cart = 1 AND did_remove = 1 AND did_purchase = 0 THEN 'removed_notpurchased'
--       WHEN did_cart = 1 AND did_remove = 0 AND did_purchase = 1 THEN 'kept_purchased'
--       WHEN did_cart = 1 AND did_remove = 0 AND did_purchase = 0 THEN 'carted_notpurchased'
--       WHEN did_cart = 0                     AND did_purchase = 0 THEN 'never_carted'
--     END AS behavior_type,
--     COUNT(DISTINCT user_id) AS user_count
--   FROM (
--     SELECT
--       user_id,
--       MAX(CASE WHEN event_type = 'cart'             THEN 1 ELSE 0 END) AS did_cart,
--       MAX(CASE WHEN event_type = 'remove_from_cart' THEN 1 ELSE 0 END) AS did_remove,
--       MAX(CASE WHEN event_type = 'purchase'         THEN 1 ELSE 0 END) AS did_purchase
--     FROM `service-492103.beauty.events_clean`
--     GROUP BY user_id
--   )
--   GROUP BY behavior_type
-- )
-- ORDER BY user_count DESC


----핵심 인사이트와 액션 제안
---- 1. view→cart 구간이 최대 이탈 구간
---- view 유저의 75.7%가 장바구니도 안 담고 이탈
---- 상품은 보는데 담지 않는 유저가 대부분
---- 액션 제안: 상품 상세 페이지 보강 

---- 2. 12월 전환율 하락
---- view 유저는 동일한데 cart -13%, purchase -18.8% 감소
---- 11월 블랙프라이데이 효과가 사라진 12월에 전환율이 떨어진 것으로 추정
---- 액션 제안: 12월 연말 선물 기획전, 11월 구매 유저 대상 12월 할인 쿠폰 발송

---- 3. carted_not_purchased 타겟 마케팅
---- 장바구니에 담았지만 구매하지 않은 유저가 9.6% (65,192명)
---- 이미 관심을 보인 유저라 전환 가능성이 높음
---- 액션 제안: 장바구니 상품 리마인드 메시지 발송, 장바구니 상품의 품절 임박 또는 가격 하락 메시지 발송



