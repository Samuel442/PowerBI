-- ------------------------------------------------
-- criação da view da tabela fato
-- ------------------------------------------------
CREATE OR REPLACE VIEW vw_fact_consumo AS 
SELECT 
    f.*,
    -- Criação da time_key: (Hora * 60) + Minuto
    (HOUR(f.date) * 60) + MINUTE(f.date) AS time_key,
    s.shift_name,
    s.shift_period
FROM fact_energy_raw f
LEFT JOIN dim_shift s 
    ON TIME(f.date) = s.full_time;
    
-- ----------------------------------------------
-- testes
-- ----------------------------------------------
SELECT COUNT(*) FROM vw_fact_consumo;

SELECT * FROM vw_fact_consumo;