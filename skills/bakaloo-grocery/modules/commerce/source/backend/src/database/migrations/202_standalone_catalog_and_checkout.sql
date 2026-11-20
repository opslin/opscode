-- The bundle uses a single demonstration storefront and the original orders tables.
CREATE SEQUENCE theme_bundle_order_number;
ALTER TABLE orders ADD COLUMN checkout_request_id uuid UNIQUE;
ALTER TABLE orders ADD COLUMN checkout_fingerprint text;

INSERT INTO users (id, phone, name, role)
VALUES ('00000000-0000-4000-8000-000000000322', '00000000322', 'Demo Shopper', 'CUSTOMER');
INSERT INTO categories (name, slug, sort_order) VALUES
  ('Produce', 'produce', 1), ('Dairy', 'dairy', 2),
  ('Pantry', 'pantry', 3), ('Snacks', 'snacks', 4);
INSERT INTO products (id, name, slug, price, sale_price, category_id, stock_quantity, unit, thumbnail_url)
SELECT item.id::uuid, item.name, item.slug, item.price, item.sale_price, category.id,
       item.stock, item.unit, item.image
FROM (VALUES
  ('11111111-1111-4111-8111-111111111111', 'Vine Tomatoes', 'vine-tomatoes', 65, 49, 'produce', 28, '500 g', 'assets/commerce/tomato.webp'),
  ('22222222-2222-4222-8222-222222222222', 'Fresh Whole Milk', 'fresh-whole-milk', 72, NULL, 'dairy', 18, '500 ml', 'assets/commerce/milk.webp'),
  ('33333333-3333-4333-8333-333333333333', 'Aged Basmati Rice', 'aged-basmati-rice', 169, 149, 'pantry', 22, '1 kg', 'assets/commerce/rice.webp'),
  ('44444444-4444-4444-8444-444444444444', 'Roasted Makhana', 'roasted-makhana', 115, 99, 'snacks', 15, '100 g', 'assets/commerce/snack.webp')
) AS item(id, name, slug, price, sale_price, category, stock, unit, image)
JOIN categories category ON category.slug = item.category;
