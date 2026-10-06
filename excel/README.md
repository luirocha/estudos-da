# Excel Avançado — Análise Olist

Dashboard construído com Power Query e tabela dinâmica a partir de dados
exportados via SQL do PostgreSQL.

## Arquivo
analise_olist.xlsx — 4 abas:
- **Dados Brutos**: CSV exportado do PostgreSQL sem modificações
- **Power Query**: transformações documentadas em 5 passos nomeados
- **Tabela Dinâmica**: faturamento com segmentador por ano e região
- **Dashboard**: 3 gráficos com títulos como conclusões + 4 KPIs

## Dados
Exportados via query SQL do dataset Olist no PostgreSQL local.
Query fonte disponível em: analise-vendas-olist/sql/01_exploracao_inicial.sql

## Como reproduzir
1. Execute a query SQL no DBeaver e exporte como CSV
2. Abra o .xlsx e clique em 'Atualizar Tudo' na guia Dados
3. O Power Query refaz todas as transformações automaticamente
