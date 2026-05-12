-- Cria o banco
CREATE DATABASE energia_db;

-- Exibe os bancos existentes
SHOW DATABASES;

-- Lista a tabela original
SELECT * FROM vw_fact_consumo;

-- Verifica a quantidade de linhas
SELECT COUNT(*) AS total_linhas
FROM vw_fact_consumo;







-- ######################################################
-- consultas para validação de medidas DAX no power bi
-- ######################################################

/* 
	GRANULARIDADE DE DADOS ELÉTRICOS:
   1. Granularidade: O medidor gera registros a cada 15 min (96 linhas/dia).
   2. Regra : Sempre uso DATE(coluna_data) no WHERE ou GROUP BY.
   3. Motivo: Se a coluna tiver Horas/Minutos, um filtro simples ignorará o 
      consumo do dia e trará apenas a meia-noite (00:00:00).
   4. Alinhamento: Este método garante que o SQL bata 100% com o Power BI 
      (onde as colunas de data também foram convertidas para 'Date Only').
*/

-- ######################################################
-- média agregada do dia
-- ######################################################
SELECT 
	AVG(total_diario) AS media_diaria 
FROM (
    SELECT 
		DATE(`date`) AS dia, 
        SUM(usage_kwh) AS total_diario
    FROM vw_fact_consumo
    WHERE DATE(`date`) = '2018-01-01'
    GROUP BY DATE(`date`)
) AS media_acumulada;






-- #################
-- consumo mínimo
-- #################
SELECT
	MIN(usage_kwh) AS consumo_minimo
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';



-- ###################
-- desvio financeiro
-- ###################
SELECT
	((consumo_total - meta_total) * 0.70) / 100 AS desvio_financeiro
FROM(
	SELECT
		SUM(usage_kwh) AS consumo_total,
        COUNT(DISTINCT DATE(`date`)) * 12500 AS meta_total
	FROM vw_fact_consumo
    WHERE DATE(`date`) = '2018-01-01'
) AS calculo_base;



-- ###################
-- Desvio de meta
-- ###################
SELECT
	consumo_total - meta_acumulada AS desvio_meta_final
FROM(
	SELECT
		SUM(usage_kwh) AS consumo_total,
        (980 * COUNT(DISTINCT DATE(`date`))) AS meta_acumulada
	FROM vw_fact_consumo
    WHERE DATE(`date`) BETWEEN '2018-01-01' AND '2018-02-01'
) AS validacao_excel;





-- #######################
-- Fator de potência médio
-- #######################
SELECT
	AVG(lagging_current_power_factor) / 100 AS f_p
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';





-- #######################
-- Horas fora da meta
-- #######################
SELECT 
	COUNT(*) * 0.25 AS horas_fora_da_meta
FROM vw_fact_consumo
WHERE lagging_current_power_factor < 92
	AND DATE(`date`) = '2018-01-01';
    
    
    
    

-- #############################################################################################################################################
-- Emissão de co2 por ineficiência (VALIDAÇÃO ESPECÍFICA: 01/01/2018, Horas Ineficientes identificadas: 10.5h Fator de Emissão (MCTI 2025): 0.03)
-- ##############################################################################################################################################
SELECT 
	DISTINCT (10.50 * 0.03) AS co2_por_ineficiencia
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';



-- ##########################
-- Total de horas monitoradas
-- ##########################
SELECT
	COUNT(*) AS total_leituras,
    COUNT(*) * 0.25 AS total_horas_monitoradas
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';




-- ##########################################################################################################################
-- Índicie de perfórmance % (VALIDAÇÃO ÍNDICE DE PERFORMANCE e Total de Leituras (Monitoradas): 96 Horas Fora da Meta: 10.50)
-- ##########################################################################################################################
SELECT 
    (96 - 10.50) / 96 AS indice_performance_decimal;
    
    
    
    
    
    
    
-- #######################
-- Limite de pico dinâmico
-- #######################
SELECT
	480 AS limite_pico_estatico,
    COUNT(*) AS qtd_leituras_acima_limite
FROM vw_fact_consumo
WHERE usage_kwh > 480 AND (`date`) = '2018-01-01';





-- ################
-- Média de consumo
-- ################
SELECT
	AVG(usage_kwh)
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';



-- ####################################################################################################################
-- Meta dinâmica /* VALIDAÇÃO META DINÂMICA: 01/01/2018 Soma das metas (Excel): 350 + 380 + 250 = 980 Dias no filtro: 1
-- ####################################################################################################################
SELECT
	(980 * 1) AS meta_dinamica;







-- ###############################################################################################################
-- Meta inteligente de consumo VALIDAÇÃO META INTELIGENTE: 01/01/2018 COUNTROWS(dim_date) = 1 SUM(dim_shift) = 980
-- ###############################################################################################################
SELECT 
	(1 * 980) AS meta_inteligente;
    
    
    

-- ###############################################################################################################################    
-- Ocorrencia de falha por turno (VALIDAÇÃO POR MÉDIA: 01/01/2018 Busca o turno que mais se aproximou ou passou da meta em média.)
-- ###############################################################################################################################
SELECT
	shift_name,
    AVG(usage_kwh) AS media_consumo,
	CASE
		WHEN shift_name = 'Turno A' THEN 350
        WHEN shift_name = 'Turno B' THEN 380
        WHEN shift_name = 'Turno C' THEN 250
	END AS meta
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01'
GROUP BY shift_name
ORDER BY (AVG(usage_kwh) / meta) DESC
LIMIT 1;




-- ###############
-- Pico de consumo
-- ###############
SELECT
	MAX(usage_kwh)
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';





-- #######################################################################################################
-- Tendencia semanal VALIDAÇÃO TENDÊNCIA SEMANAL (MÉDIA MÓVEL 7 DIAS) Intervalo: 26/12/2017 até 01/01/2018
-- #######################################################################################################
SELECT
	AVG(total_diario) AS tendencia_semanal
FROM(
	SELECT
		DATE(`date`) AS dia,
        SUM(usage_kwh) AS total_diario
	FROM vw_fact_consumo
    WHERE DATE(`date`) BETWEEN DATE_SUB('2018-01-01', INTERVAL 6 DAY) AND '2018-01-01'
    GROUP BY DATE(`date`)
) AS resumo_7_dias;




-- ###############
-- Total consumido
-- ###############
SELECT
	SUM(usage_kwh) AS total_consumido
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';



-- ####################
-- Total emitido de co2
-- ####################
SELECT 
	SUM(co2tco2) AS co2_emitido
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';



-- ##########################
-- Total de horas monitoradas
-- ##########################
SELECT 
    COUNT(*) AS total_registros,
    (COUNT(*) / 4.0) AS total_horas_calculadas
FROM vw_fact_consumo
WHERE DATE(`date`) = '2018-01-01';









-- #################################################################
-- Total de horas monitoradas Fórmula: (Atual - Anterior) / Anterior
-- #################################################################
SELECT 
	132350 AS consumo_março,
    93170 AS consumo_fevereiro,
    ((132350 - 93170) / 1000.0) AS variacao_percentual;