#/bin/bash
# ================================================================================ #
# AUTOR: Eduardo Zuchetti                                                          #
# DESCRIÇÃO: Teste de um único site                                                #
# LICENSE: GPL 3.0                                                                 #
# GitHub: https://github.com/eduzuchetti/ShellScripts                              #
# ================================================================================ #

# ================================================================================ #
# Monitoramento do tempo de resposta e resposta https                              #
# ================================================================================ #

# Configurações
URL="www.example.com"           # URL a ser monitorada
SERVICO="URL_www.example.com"   # Nome do serviço

# Verifica status HTTP
status=$(curl -s -i -k --connect-timeout 3 $URL | head -1 | awk '{print $2}')

# Verifica o tempo de resposta da página
time=$(curl --connect-timeout 3 -o /dev/null -s -w %{time_total}\\n $URL)


if [[ status -eq 200 ]]; then
    echo "0 Monitoria_$SERVICO count=200;300;400; $URL - $status OK || Página carregada em $time ms"
else
    echo "2 Monitoria_$SERVICO count=200;300;400; $URL - STATUS $status || Página carregada em $time ms"
fi
