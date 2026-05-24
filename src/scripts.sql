-- Триггерная функция для проверки диапазонов значений
CREATE OR REPLACE FUNCTION trg_check_characteristic_constraints()
    RETURNS TRIGGER AS $$
DECLARE
    v_char_kind VARCHAR;
    v_data_type VARCHAR;
    v_min NUMERIC;
    v_max NUMERIC;
BEGIN
    -- Получаем правила из шаблона
    SELECT char_kind, data_type, min_value, max_value
    INTO v_char_kind, v_data_type, v_min, v_max
    FROM characteristic_templates
    WHERE id = NEW.template_id;

    -- Проверка для численных параметров
    IF v_char_kind = 'PARAMETER' AND v_data_type = 'NUMBER' THEN
        IF NEW.num_value IS NOT NULL THEN
            IF v_min IS NOT NULL AND NEW.num_value < v_min THEN
                RAISE EXCEPTION 'Значение % меньше допустимого минимума (%)', NEW.num_value, v_min;
            END IF;
            IF v_max IS NOT NULL AND NEW.num_value > v_max THEN
                RAISE EXCEPTION 'Значение % больше допустимого максимума (%)', NEW.num_value, v_max;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Привязка триггера к таблице значений
CREATE TRIGGER trg_validate_char_value
    BEFORE UPDATE ON characteristic_values
    FOR EACH ROW EXECUTE FUNCTION trg_check_characteristic_constraints();


-- 1. Создание нового типа ХО
CREATE OR REPLACE FUNCTION create_operation_type(
    p_sys_code VARCHAR,
    p_name VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    INSERT INTO operation_types (sys_code, name)
    VALUES (p_sys_code, p_name)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;


-- 2. Добавление шаблона характеристики (параметра или роли)
CREATE OR REPLACE FUNCTION add_characteristic_template(
    p_op_type_id INTEGER,
    p_name VARCHAR,
    p_char_kind VARCHAR, -- 'PARAMETER' или 'ROLE'
    p_data_type VARCHAR, -- 'NUMBER' или 'TEXT'
    p_min_val NUMERIC DEFAULT NULL,
    p_max_val NUMERIC DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    INSERT INTO characteristic_templates
    (operation_type_id, name, char_kind, data_type, min_value, max_value)
    VALUES
        (p_op_type_id, p_name, p_char_kind, p_data_type, p_min_val, p_max_val)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;


-- 3. Формирование экземпляра ХО
CREATE OR REPLACE FUNCTION create_business_operation(
    p_op_type_id INTEGER,
    p_doc_number VARCHAR,
    p_doc_date TIMESTAMP DEFAULT NOW()
) RETURNS INTEGER AS $$
DECLARE
    v_new_op_id INTEGER;
BEGIN
    -- Создаем шапку документа
    INSERT INTO business_operations (operation_type_id, doc_number, doc_date)
    VALUES (p_op_type_id, p_doc_number, p_doc_date)
    RETURNING id INTO v_new_op_id;

    -- ВАЖНО: Автоматически создаем пустые записи для всех параметров и ролей этого типа ХО
    -- Это позволит пользователю в интерфейсе просто обновить (UPDATE) нужные поля
    INSERT INTO characteristic_values (operation_id, template_id, num_value, txt_value)
    SELECT v_new_op_id, id, NULL, NULL
    FROM characteristic_templates
    WHERE operation_type_id = p_op_type_id;

    RETURN v_new_op_id;
END;
$$ LANGUAGE plpgsql;


-- 4. Редактирование значения (универсальная процедура для параметра и роли)
CREATE OR REPLACE FUNCTION set_characteristic_value(
    p_operation_id INTEGER,
    p_template_id INTEGER,
    p_num_value NUMERIC DEFAULT NULL,
    p_txt_value TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Обновляем заранее созданную пустую запись.
    -- Если данные нарушают границы (min/max), сработает наш триггер и выдаст ошибку.
    UPDATE characteristic_values
    SET num_value = p_num_value,
        txt_value = p_txt_value
    WHERE operation_id = p_operation_id
      AND template_id = p_template_id;
END;
$$ LANGUAGE plpgsql;


-- 4.1. Добавление позиции в табличную часть (Спецификацию)
CREATE OR REPLACE FUNCTION add_operation_specification(
    p_operation_id INTEGER,
    p_item_name VARCHAR,
    p_quantity NUMERIC,
    p_price NUMERIC
) RETURNS INTEGER AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    INSERT INTO operation_specifications (operation_id, item_name, quantity, price)
    VALUES (p_operation_id, p_item_name, p_quantity, p_price)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;


-- 5. Поиск ХО заданного класса (Возвращает реестр документов)
CREATE OR REPLACE FUNCTION find_operations_by_type(
    p_sys_code VARCHAR
) RETURNS TABLE (
                    operation_id INTEGER,
                    doc_number VARCHAR,
                    doc_date TIMESTAMP,
                    total_lines BIGINT,
                    total_amount NUMERIC
                ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            b.id,
            b.doc_number,
            b.doc_date,
            COUNT(s.id) AS total_lines,
            COALESCE(SUM(s.quantity * s.price), 0) AS total_amount
        FROM business_operations b
                 JOIN operation_types t ON b.operation_type_id = t.id
                 LEFT JOIN operation_specifications s ON b.id = s.operation_id
        WHERE t.sys_code = p_sys_code
        GROUP BY b.id, b.doc_number, b.doc_date
        ORDER BY b.doc_date DESC;
END;
$$ LANGUAGE plpgsql;


-- 6. Представление всех характеристик конкретной ХО (Разворачивание документа)
CREATE OR REPLACE FUNCTION get_operation_full_details(
    p_operation_id INTEGER
) RETURNS TABLE (
                    char_name VARCHAR,
                    char_kind VARCHAR,
                    data_type VARCHAR,
                    numeric_value NUMERIC,
                    text_value TEXT
                ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            t.name,
            t.char_kind,
            t.data_type,
            v.num_value,
            v.txt_value
        FROM characteristic_values v
                 JOIN characteristic_templates t ON v.template_id = t.id
        WHERE v.operation_id = p_operation_id
        ORDER BY t.char_kind DESC, t.name;
END;
$$ LANGUAGE plpgsql;