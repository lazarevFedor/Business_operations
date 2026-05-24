-- Удаление таблиц контура фактов
DROP TABLE IF EXISTS operation_specifications CASCADE;
DROP TABLE IF EXISTS characteristic_values CASCADE;
DROP TABLE IF EXISTS business_operations CASCADE;

-- Удаление таблиц контура метаданных
DROP TABLE IF EXISTS characteristic_templates CASCADE;
DROP TABLE IF EXISTS operation_types CASCADE;