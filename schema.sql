-- Vitaly App Database Schema for InsForge Postgres

CREATE TABLE IF NOT EXISTS public.categories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    category_code integer UNIQUE NOT NULL,
    category_name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.materials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    material_code text UNIQUE NOT NULL,
    category_code integer,
    material_name text NOT NULL,
    stone_type text,
    finish text,
    material_image_url text,
    erp_description text,
    erp_unit text DEFAULT 'sqm',
    color_family text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stone_inventory (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    material_code text,
    slab_no text UNIQUE NOT NULL,
    length_mm numeric DEFAULT 0,
    width_mm numeric DEFAULT 0,
    thickness_mm numeric DEFAULT 20,
    area_sqm numeric DEFAULT 0,
    rack_code text DEFAULT 'WAREHOUSE',
    photo_url text,
    status text DEFAULT 'available',
    notes text,
    batch_id text,
    qr_code_data text,
    received_date date DEFAULT CURRENT_DATE,
    reserved_price numeric,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customers (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_code text,
    customer_name text NOT NULL,
    phone text,
    address text,
    balance_due numeric DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reservations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_id text,
    slab_ids jsonb DEFAULT '[]'::jsonb,
    expiry_date date,
    notes text,
    status text DEFAULT 'Active',
    deposit_amount numeric DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    price_sqm numeric DEFAULT 0,
    total_sqm numeric DEFAULT 0,
    total_amount numeric DEFAULT 0,
    amount_paid numeric DEFAULT 0,
    balance_due numeric DEFAULT 0,
    is_picked_up boolean DEFAULT false,
    status text DEFAULT 'completed',
    pickup_date date,
    customer_name text,
    invoice_no text,
    slab_ids jsonb DEFAULT '[]'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.material_audits (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    material_id text UNIQUE NOT NULL,
    code_text text,
    material_name text,
    category_code integer DEFAULT 12,
    physical_sqm numeric,
    is_counted boolean DEFAULT false,
    erp_in_sqm numeric DEFAULT 0,
    erp_out_sqm numeric DEFAULT 0,
    erp_balance_override numeric,
    app_sqm_override numeric,
    last_erp_update text,
    notes text,
    last_count_date text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Seed Categories matching AppSheet / Vitaly App categories
INSERT INTO public.categories (category_code, category_name) VALUES
(10, 'Marble'),
(11, 'Granite'),
(12, 'Quartz'),
(13, 'Onyx'),
(14, 'Travertine'),
(15, 'Limestone'),
(16, 'Quartzite'),
(17, 'Porcelain'),
(18, 'Semi-Precious')
ON CONFLICT (category_code) DO NOTHING;

-- Grant permissions for anon & authenticated roles
GRANT ALL ON TABLE public.categories TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.materials TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.stone_inventory TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.customers TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.reservations TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.sales TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.material_audits TO anon, authenticated, service_role;

-- Disable RLS on these tables or allow full access
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stone_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_audits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon all on categories" ON public.categories;
CREATE POLICY "Allow anon all on categories" ON public.categories FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on materials" ON public.materials;
CREATE POLICY "Allow anon all on materials" ON public.materials FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on stone_inventory" ON public.stone_inventory;
CREATE POLICY "Allow anon all on stone_inventory" ON public.stone_inventory FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on customers" ON public.customers;
CREATE POLICY "Allow anon all on customers" ON public.customers FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on reservations" ON public.reservations;
CREATE POLICY "Allow anon all on reservations" ON public.reservations FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on sales" ON public.sales;
CREATE POLICY "Allow anon all on sales" ON public.sales FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on material_audits" ON public.material_audits;
CREATE POLICY "Allow anon all on material_audits" ON public.material_audits FOR ALL TO public USING (true) WITH CHECK (true);
