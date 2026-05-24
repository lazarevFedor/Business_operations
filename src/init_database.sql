-- 1. Справочник типов документов (Варка, Отгрузка и т.д.)
CREATE TABLE operation_types (
    id SERIAL PRIMARY KEY,
    sys_code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL
);

-- 2. Конструктор структуры документов (Шаблоны характеристик)
CREATE TABLE characteristic_templates (
    id SERIAL PRIMARY KEY,
    operation_type_id INTEGER NOT NULL REFERENCES operation_types(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    char_kind VARCHAR(20) NOT NULL CHECK (char_kind IN ('PARAMETER', 'ROLE')),
    data_type VARCHAR(20) NOT NULL CHECK (data_type IN ('NUMBER', 'TEXT', 'ENUM')),
    min_value NUMERIC(10,2),
    max_value NUMERIC(10,2),
    allowed_values TEXT
);

-- 3. Реестр проведенных документов
CREATE TABLE business_operations (
    id SERIAL PRIMARY KEY,
    operation_type_id INTEGER NOT NULL REFERENCES operation_types(id),
    doc_number VARCHAR(50) NOT NULL,
    doc_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 4. Хранилище фактических значений параметров и ролей
CREATE TABLE characteristic_values (
    id SERIAL PRIMARY KEY,
    operation_id INTEGER NOT NULL REFERENCES business_operations(id) ON DELETE CASCADE,
    template_id INTEGER NOT NULL REFERENCES characteristic_templates(id),
    num_value NUMERIC(10,2),
    txt_value TEXT
);

-- 5. Табличная часть документа (Материальный учет сырья/продукции)
CREATE TABLE operation_specifications (
    id SERIAL PRIMARY KEY,
    operation_id INTEGER NOT NULL REFERENCES business_operations(id) ON DELETE CASCADE,
    item_name VARCHAR(150) NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    price NUMERIC(10,2) NOT NULL
);