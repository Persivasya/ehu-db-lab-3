-- 1
WITH film_rentals AS (
    SELECT 
        f.release_year,
        f.film_id,
        f.title,
        COUNT(r.rental_id) as rental_count,
        ROW_NUMBER() OVER (PARTITION BY f.release_year ORDER BY COUNT(r.rental_id) DESC, f.film_id) as rn
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.release_year, f.film_id, f.title
)
SELECT 
    release_year,
    film_id,
    title,
    rental_count
FROM film_rentals
WHERE rn = 1
ORDER BY release_year;

-- 2
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    COUNT(DISTINCT fa.film_id) as comedy_film_count
FROM actor a
JOIN film_actor fa ON a.actor_id = fa.actor_id
JOIN film_category fc ON fa.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE c.name = 'Comedy'
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY comedy_film_count DESC
LIMIT 5;

-- 3
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name
FROM actor a
WHERE NOT EXISTS (
    SELECT 1
    FROM film_actor fa
    JOIN film_category fc ON fa.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    WHERE fa.actor_id = a.actor_id
    AND c.name = 'Action'
)
ORDER BY a.last_name, a.first_name;

-- 4
WITH film_rentals_by_genre AS (
    SELECT 
        c.name as genre,
        f.film_id,
        f.title,
        COUNT(r.rental_id) as rental_count,
        ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY COUNT(r.rental_id) DESC, f.film_id) as rn
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    GROUP BY c.name, f.film_id, f.title
)
SELECT 
    genre,
    film_id,
    title,
    rental_count
FROM film_rentals_by_genre
WHERE rn <= 3
ORDER BY genre, rental_count DESC, film_id;

-- 5
SELECT 
    release_year,
    COUNT(*) as films_count,
    SUM(COUNT(*)) OVER (ORDER BY release_year) as cumulative_total
FROM film
GROUP BY release_year
ORDER BY release_year;

-- 6
WITH monthly_rentals AS (
    SELECT 
        DATE_TRUNC('month', r.rental_date) as rental_month,
        COUNT(*) as total_rentals,
        SUM(CASE WHEN c.name = 'Animation' THEN 1 ELSE 0 END) as animation_rentals
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    GROUP BY DATE_TRUNC('month', r.rental_date)
)
SELECT 
    TO_CHAR(rental_month, 'YYYY-MM') as month,
    total_rentals,
    animation_rentals,
    ROUND(100.0 * animation_rentals / NULLIF(total_rentals, 0), 2) as animation_percentage
FROM monthly_rentals
ORDER BY rental_month;

-- 7
WITH actor_film_counts AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        SUM(CASE WHEN c.name = 'Action' THEN 1 ELSE 0 END) as action_count,
        SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) as drama_count
    FROM actor a
    JOIN film_actor fa ON a.actor_id = fa.actor_id
    JOIN film_category fc ON fa.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Action', 'Drama')
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT 
    actor_id,
    first_name,
    last_name,
    action_count,
    drama_count
FROM actor_film_counts
WHERE action_count > drama_count
ORDER BY action_count DESC, last_name, first_name;

-- 8
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(p.amount) as total_spent
FROM customer c
JOIN payment p ON c.customer_id = p.customer_id
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category cat ON fc.category_id = cat.category_id
WHERE cat.name = 'Comedy'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 5;

-- 9
SELECT 
    TRIM(SPLIT_PART(address, ' ', -1)) as street_type,
    COUNT(*) as address_count
FROM address
WHERE address IS NOT NULL AND address != ''
GROUP BY TRIM(SPLIT_PART(address, ' ', -1))
ORDER BY address_count DESC;

-- 10
WITH rating_category_counts AS (
    SELECT 
        f.rating,
        c.name as category,
        COUNT(*) as films_in_category
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    GROUP BY f.rating, c.name
),
rating_totals AS (
    SELECT 
        rating,
        COUNT(*) as total
    FROM film
    GROUP BY rating
),
top_categories AS (
    SELECT 
        rating,
        category,
        films_in_category,
        ROW_NUMBER() OVER (PARTITION BY rating ORDER BY films_in_category DESC, category) as rn
    FROM rating_category_counts
)
SELECT 
    rt.rating,
    rt.total,
	MAX(CASE WHEN tc.rn = 1 THEN tc.category || ' (' || tc.films_in_category || ')' END) AS category_1,
    MAX(CASE WHEN tc.rn = 2 THEN tc.category || ' (' || tc.films_in_category || ')' END) AS category_2,
    MAX(CASE WHEN tc.rn = 3 THEN tc.category || ' (' || tc.films_in_category || ')' END) AS category_3
FROM rating_totals rt
LEFT JOIN top_categories tc ON rt.rating = tc.rating
GROUP BY rt.rating, rt.total
ORDER BY rt.rating;
