#!/usr/bin/bash

docker-compose exec mysql-cliente ./run.sh -h mysql-server -u root -prootpassword -e "SELECT 'CONEXÃO BEM SUCEDIDA' AS status;"
