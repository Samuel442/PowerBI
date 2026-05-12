-- ------------------------------------------------
-- criação da dimensão de tipo de carga
-- ------------------------------------------------
CREATE VIEW dim_load_type AS
SELECT DISTINCT 
	load_type,                      -- chave que liga a fato
    CASE
		WHEN load_type = 'Light_Load' THEN 'Carga Leve'
        WHEN load_type = 'Medium_Load' THEN 'Carga Média'
        When load_type = 'Maximum_Load' THEN 'Carga Máxima'
        ELSE load_type -- mantém o original se surgir algo novo (Falback)
	END AS regime_carga
FROM fact_energy_raw;

SELECT * FROM dim_load_type;



-- ------------------------------------------------
-- criação da dimensão status da semana
-- ------------------------------------------------
CREATE VIEW dim_week_status AS
SELECT DISTINCT 
    week_status, -- Chave original para o relacionamento
    CASE 
        WHEN week_status = 'Weekday' THEN 'Dia Útil'
        WHEN week_status = 'Weekend' THEN 'Fim de Semana'
        ELSE week_status -- Fallback para prevenir erros de novos dados
    END AS status_da_semana
FROM fact_energy_raw;

-- Testar a criação
SELECT * FROM dim_week_status;


-- ------------------------------------------------
-- criação da dimensão time
-- ------------------------------------------------
DROP VIEW IF EXISTS dim_shift;
DROP VIEW IF EXISTS dim_time;
DROP TABLE IF EXISTS dim_time;

-- criação da time
CREATE TABLE dim_time AS
SELECT 
    t.n AS time_key,
    FLOOR(t.n / 60) AS hour,
    t.n % 60 AS minute,
    SEC_TO_TIME(t.n * 60) AS full_time
FROM (
    SELECT a.N + b.N * 10 + c.N * 100 + d.N * 1000 AS n
    FROM 
        (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN 
        (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN 
        (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
    CROSS JOIN 
        (SELECT 0 N UNION ALL SELECT 1) d
) t
WHERE t.n < 1440;

ALTER TABLE dim_time ADD PRIMARY KEY (time_key);



-- ------------------------------------------------
-- criação da dimensão date
-- ------------------------------------------------
CREATE OR REPLACE VIEW dim_date AS
WITH RECURSIVE days AS (
    -- Define o ponto de partida (Primeiro dia de 2018)
    SELECT CAST('2018-01-01' AS DATE) AS date_ref
    UNION ALL
    -- Adiciona um dia por iteração até o fim do ano
    SELECT DATE_ADD(date_ref, INTERVAL 1 DAY)
    FROM days
    WHERE date_ref < '2018-12-31'
)
SELECT 
    date_ref AS Date,
    YEAR(date_ref) AS YEAR,
    MONTH(date_ref) AS MONTH,
    -- Tradução dos Meses para PT-BR
    CASE MONTH(date_ref)
        WHEN 1 THEN 'janeiro' WHEN 2 THEN 'fevereiro' WHEN 3 THEN 'março'
        WHEN 4 THEN 'abril' WHEN 5 THEN 'maio' WHEN 6 THEN 'junho'
        WHEN 7 THEN 'julho' WHEN 8 THEN 'agosto' WHEN 9 THEN 'setembro'
        WHEN 10 THEN 'outubro' WHEN 11 THEN 'novembro' WHEN 12 THEN 'dezembro'
    END AS month_name,
    DAY(date_ref) AS DAY,
    -- Tradução dos Dias da Semana
    CASE WEEKDAY(date_ref)
        WHEN 0 THEN 'segunda-feira' WHEN 1 THEN 'terça-feira' WHEN 2 THEN 'quarta-feira'
        WHEN 3 THEN 'quinta-feira' WHEN 4 THEN 'sexta-feira' WHEN 5 THEN 'sábado'
        WHEN 6 THEN 'domingo'
    END AS day_name,
    WEEKOFYEAR(date_ref) AS week_number,
    -- Flag de Fim de Semana (1 para Sim, 0 para Não)
    CASE WHEN WEEKDAY(date_ref) IN (5, 6) THEN 1 ELSE 0 END AS is_weekend
FROM days;

-- Verificação da tabela
SELECT * FROM dim_date LIMIT 33;



-- -----------------------------------------------
-- Criação da dimensão turno (análise operacional)
-- -----------------------------------------------
CREATE VIEW dim_shift AS
SELECT 
    time_key,
    full_time,
    CASE 
        WHEN hour >= 6 AND hour < 14 THEN 'Turno A'
        WHEN hour >= 14 AND hour < 22 THEN 'Turno B'
        ELSE 'Turno C'
    END AS shift_name,
    CASE 
        WHEN hour >= 6 AND hour < 14 THEN 'Manhã'
        WHEN hour >= 14 AND hour < 22 THEN 'Tarde'
        ELSE 'Noite/Madrugada'
    END AS shift_period
FROM dim_time;


-- n de linhas tabela tempo
SELECT COUNT(*) FROM dim_time;

-- n de linhas tabela turno
SELECT COUNT(*) FROM dim_shift;