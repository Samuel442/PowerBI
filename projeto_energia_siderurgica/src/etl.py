# Importação das bibliotecas necessárias para o pipeline ETL:
# - pandas: manipulação e transformação de dados
# - re: limpeza e padronização de strings (regex)
# - os: acesso a variáveis de ambiente
# - dotenv: carregamento seguro de credenciais (.env)
# - pathlib: manipulação de caminhos de forma robusta
# - sqlalchemy: conexão e carga de dados no banco (MySQL)
import pandas as pd
import re
import os
from dotenv import load_dotenv
from pathlib import Path
import sqlalchemy

# =========================
# LOAD
# =========================
# Responsável pela etapa de extração do ETL.
# Lê o arquivo CSV de origem e retorna um DataFrame para processamento.
def load_data(path):
    df = pd.read_csv(path)
    return df

# =========================
# STANDARDIZE COLUMNS
# =========================
# Padroniza os nomes das colunas para um formato consistente (snake_case),
# removendo espaços, caracteres especiais e normalizando para minúsculas.
# Isso evita erros em consultas, integrações e facilita a manutenção do pipeline.
def standardize_columns(df):
    def clean_col(col):
        col = col.strip().lower()              # remove espaços e coloca em minúsculo
        col = col.replace(" ", "_")            # substitui espaços por underscore
        col = col.replace(".", "_")            # substitui pontos por underscore
        col = re.sub(r"[()]", "", col)         # remove parênteses
        col = re.sub(r"[^a-z0-9_]", "", col)   # remove caracteres especiais
        col = re.sub(r"_+", "_", col)          # remove múltiplos underscores
        return col

    df.columns = [clean_col(col) for col in df.columns]
    return df


# =========================
# TRANSFORM
# =========================
# Responsável pela transformação dos dados:
# - Converte a coluna de data para formato datetime
# - Padroniza valores textuais (remoção de espaços e capitalização)
# - Converte colunas categóricas para o tipo 'category' para otimização de memória
def transform_data(df):
    # Converte string para datetime (essencial para análises temporais)
    df['date'] = pd.to_datetime(df['date'], format='%d/%m/%Y %H:%M')

    # Padroniza colunas categóricas (remove espaços e normaliza capitalização)
    df['day_of_week'] = df['day_of_week'].str.strip().str.title()
    df['load_type'] = df['load_type'].str.strip().str.title()
    df['week_status'] = df['week_status'].str.strip().str.title()

    # Converte para tipo category (melhor uso de memória e semântica correta)
    categorical_cols = ['week_status', 'day_of_week', 'load_type']
    for col in categorical_cols:
        df[col] = df[col].astype('category')

    return df

# =========================
# VALIDATE
# =========================
# Realiza validações de consistência dos dados:
# - Verifica se o dia da semana corresponde à data
# - Garante ordenação temporal
# - Analisa a frequência dos registros (intervalos de tempo)

def validate_data(df):
    # Verifica inconsistências entre a data e o dia da semana informado
    inconsistencies = (df['date'].dt.day_name() != df['day_of_week']).sum()
    print(f"Inconsistencies: {inconsistencies}")

    # Ordena os dados por data para garantir sequência temporal correta
    df = df.sort_values('date')

    # Verifica a frequência dos registros (esperado: intervalo fixo de tempo)
    print(df['date'].diff().value_counts())

    return df.reset_index(drop=True)


# =========================
# DATA QUALITY CHECK
# =========================
# Executa verificações gerais de qualidade dos dados:
# - Tipos de dados
# - Valores nulos
# - Registros duplicados
# - Estatísticas descritivas
# - Valores únicos das colunas categóricas

def quality_check(df):
    print("\n=== DATA QUALITY CHECK ===")

    print("\nTipos de dados:")
    print(df.dtypes)

    print("\nValores nulos:")
    print(df.isnull().sum())

    print("\nDuplicados:")
    print(df.duplicated().sum())

    print("\nEstatísticas:")
    print(df.describe())

    print("\nCategorias:")
    for col in ['week_status', 'day_of_week', 'load_type']:
        print(f"{col}: {df[col].unique()}")


# =========================
# CONEXÃO COM BANCO
# =========================
# Cria a engine de conexão com o banco MySQL utilizando credenciais
# armazenadas em variáveis de ambiente (.env), garantindo segurança
# e flexibilidade para diferentes ambientes (dev, homolog, prod).
def get_engine():
    # Carrega variáveis do arquivo .env localizado na raiz do projeto
    load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

    # Recupera credenciais do ambiente
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASS")
    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT")
    db = os.getenv("DB_NAME")

    # Cria engine de conexão com o MySQL via SQLAlchemy
    engine = sqlalchemy.create_engine(
        f"mysql+pymysql://{user}:{password}@{host}:{port}/{db}"
    )

    return engine


# =========================
# MAIN
# =========================
def main():
    print("Entrou no main")
    path = "data/Steel_industry_data.csv"
    # LOAD
    df = load_data(path)
    # STANDARDIZE
    df = standardize_columns(df)
    # BUSINESS RENAME
    df = df.rename(columns={
        'weekstatus': 'week_status'
    })
    # TRANSFORM
    df = transform_data(df)
    # VALIDATE
    df = validate_data(df)
    # SORT (garantia final)
    df = df.sort_values('date').reset_index(drop=True)
    # DEBUG VISUAL
    print("\n=== HEAD ===")
    print(df.head())
    print("\n=== TAIL ===")
    print(df.tail())
    # QUALITY
    quality_check(df)
    # CONNECT FIRST (fail fast)
    engine = get_engine()
    with engine.connect() as conn:
        print("Conexão com MySQL OK!")
    # LOAD
    df.to_sql(
        name='fact_energy_raw',
        con=engine,
        if_exists='replace',
        index=False
    )
    print("Dados enviados para o MySQL!")


if __name__ == "__main__":
    print("Chamando main()")
    main()

