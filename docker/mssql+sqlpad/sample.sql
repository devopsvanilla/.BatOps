-- Criar tabela de exemplo
CREATE TABLE VendasRegioes (
    Regiao NVARCHAR(50),
    VendasJaneiro INT,
    VendasFevereiro INT,
    VendasMarco INT
);

-- Inserir dados de exemplo
INSERT INTO VendasRegioes VALUES 
('Sudeste', 12500, 14800, 16200),
('Sul', 9800, 11200, 11900),
('Nordeste', 7500, 8200, 9100),
('Norte', 4500, 5200, 6100),
('Centro-Oeste', 6800, 7400, 8500);

-- Consulta simples para gráfico de barras (Vendas por Região - Total)
SELECT 
    Regiao,
    (VendasJaneiro + VendasFevereiro + VendasMarco) as TotalVendas
FROM VendasRegioes
ORDER BY TotalVendas DESC;
