# Documentação: Teste de Velocidade da Internet

## Propósito

Este script mede a velocidade da conexão com a Internet a cada 30 minutos e salva os resultados em arquivos diários.

## Requisitos para Execução

- Ubuntu ou qualquer sistema baseado em Linux
- Ferramenta `speedtest-cli` instalada. Caso não esteja instalada, o script verificará e perguntará se deseja instalá-la automaticamente. Para instalar manualmente, use:
  ```bash
  sudo apt update && sudo apt install -y speedtest-cli
  ```

### Sobre o speedtest-cli

O `speedtest-cli` é uma ferramenta de linha de comando para medir a velocidade da conexão com a Internet. Ele utiliza o serviço Speedtest.net para realizar os testes e fornece informações como:
- Velocidade de download
- Velocidade de upload
- Latência (ping)

Para mais informações, visite o repositório oficial: [speedtest-cli no GitHub](https://github.com/sivel/speedtest-cli).

## Como Executar

1. Certifique-se de que o script `test-internet-speed.sh` está no diretório `./tests/`.
2. Torne o script executável:
   ```bash
   chmod +x ./tests/test-internet-speed.sh
   ```
3. Agende o script no crontab para execução a cada 30 minutos:
   ```bash
   crontab -e
   ```
   Adicione a seguinte linha ao crontab:
   ```bash
   */30 * * * * /caminho/para/o/script/tests/test-internet-speed.sh --save /caminho/para/diretorio
   ```

## Onde os Dados São Salvos

Os resultados são salvos no diretório especificado pelo usuário (ou no diretório padrão `/tmp/test-internet-speed`), com um arquivo para cada dia no formato `YYYY-MM-DD.log`. Os dados são armazenados no formato JSON. Abaixo está uma tabela com os campos disponíveis:

| Campo               | Descrição                                                                 |
|---------------------|---------------------------------------------------------------------------|
| download            | Velocidade de download em bits por segundo                               |
| upload              | Velocidade de upload em bits por segundo                                 |
| ping                | Latência em milissegundos                                                |
| server.url          | URL do servidor utilizado para o teste                                   |
| server.lat          | Latitude do servidor                                                     |
| server.lon          | Longitude do servidor                                                    |
| server.name         | Nome do servidor                                                         |
| server.country      | País do servidor                                                         |
| server.cc           | Código do país do servidor                                               |
| server.sponsor      | Patrocinador do servidor                                                 |
| server.id           | ID do servidor                                                           |
| server.host         | Host do servidor                                                         |
| server.d            | Distância até o servidor em quilômetros                                  |
| server.latency      | Latência do servidor em milissegundos                                    |
| timestamp           | Data e hora do teste em formato ISO 8601                                |
| bytes_sent          | Quantidade de bytes enviados                                             |
| bytes_received      | Quantidade de bytes recebidos                                            |
| client.ip           | Endereço IP do cliente                                                   |
| client.lat          | Latitude do cliente                                                      |
| client.lon          | Longitude do cliente                                                     |
| client.isp          | Provedor de serviços de Internet (ISP)                                   |
| client.isprating    | Avaliação do ISP                                                         |
| client.rating       | Avaliação geral                                                          |
| client.ispdlavg     | Média de download do ISP                                                 |
| client.ispulavg     | Média de upload do ISP                                                   |
| client.loggedin     | Status de login                                                          |
| client.country      | País do cliente                                                          |
