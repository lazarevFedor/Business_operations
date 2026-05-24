-- 1. Ведение классификатора ХО
-- Создаем тип документа "Акт варки сусла" (ожидаемый ID = 1)
SELECT create_operation_type('BREW_ACT', 'Акт варки сусла');

-- Создаем тип документа "Отгрузка готовой продукции" (ожидаемый ID = 2)
SELECT create_operation_type('SHIPMENT', 'Отгрузка готового пива');

-- 2. Конструирование шаблонов ХО
-- Добавляем параметр "Температура затирания" для Акта варки (ID типа = 1)
-- Устанавливаем строгий диапазон от 62.0 до 72.0 градусов
SELECT add_characteristic_template(
    p_op_type_id := 1,
    p_name := 'Температура затирания, °C',
    p_char_kind := 'PARAMETER',
    p_data_type := 'NUMBER',
    p_min_val := 62.00,
    p_max_val := 72.00
); -- Ожидаемый ID шаблона = 1

-- Добавляем роль "Главный пивовар" для Акта варки
SELECT add_characteristic_template(
    p_op_type_id := 1,
    p_name := 'Главный пивовар',
    p_char_kind := 'ROLE',
    p_data_type := 'TEXT'
); -- Ожидаемый ID шаблона = 2

-- 3. Формирование экземпляров ХО
-- Создаем документ варки (ожидаемый ID документа = 1)
-- ВАЖНО: В этот момент функция автоматически создаст пустые слоты для Температуры и Пивовара!
SELECT create_business_operation(
    p_op_type_id := 1,
    p_doc_number := 'ВАРКА-001'::VARCHAR,
    p_doc_date := LOCALTIMESTAMP
);

-- 4. Редактирование значений параметров и назначений ролей
-- Фиксируем корректную температуру варки (68.5 градусов)
-- ID документа = 1, ID шаблона температуры = 1
SELECT set_characteristic_value(
    p_operation_id := 1,
    p_template_id := 1,
    p_num_value := 68.5::NUMERIC
);

-- Назначаем сотрудника на роль пивовара
-- ID документа = 1, ID шаблона роли = 2
SELECT set_characteristic_value(
    p_operation_id := 1,
    p_template_id := 2,
    p_txt_value := 'Иванов И.И.'::TEXT
);

-- Дополнительно: Добавляем потраченное сырье в спецификацию (Табличную часть)
SELECT add_operation_specification(1, 'Солод Пэйл Эль'::VARCHAR, 200.000::NUMERIC, 75.00::NUMERIC);
SELECT add_operation_specification(1, 'Хмель Каскад'::VARCHAR, 5.000::NUMERIC, 1200.00::NUMERIC);

-- Пытаемся установить температуру 95 градусов (Должно вызвать ошибку!)
SELECT set_characteristic_value(
    p_operation_id := 1,
    p_template_id := 1,
    p_num_value := 95.0::NUMERIC
);

-- 5. Поиск ХО заданного класса
-- Получаем список всех Актов варки (SYS_CODE = 'BREW_ACT') с посчитанной суммой сырья
SELECT * FROM find_operations_by_type('BREW_ACT');

-- 6. Представление всех характеристик конкретной ХО
-- Выводим "развернутую" карточку документа №1 (наша варка)
SELECT * FROM get_operation_full_details(1);