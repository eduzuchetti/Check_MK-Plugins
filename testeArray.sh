#!/bin/bash
# ================================================================================ #
# AUTOR: Eduardo Zuchetti                                                          #
# DESCRIÇÃO: Teste de sites pela resposta do cabeçalho HTTP para plugins do Nagios #
# LICENSE: GPL 3.0                                                                 #
# 
# ================================================================================ #

# ================================================================================ #
# Primeira lista de IP's a ser monitorada (IPs ou DNS únicos)                      #
# Para monitorar um DNS que aponta para um balancer com vários IPs, olhe o próximo #
# ================================================================================ #

# IMPORTANTE Deixar um 'espaço' depois do IP ou DNS para separar os valores
# IMPORTANTE Não colocar o espaço depois do último valor
VARIAVEL01=(
    192.168.1.1 
    www.example.com 
    www.facebook.com 
    www.google.com.br 
    localhost
)

# Laço de repetição para fazer a mesma verificação a baixo para cada IP/DNS
for (( i=0; i<7; i++ ))
do
    # Verifica tempo de resposta do IP/DNS pelo cURL
    STATUS=$(curl -s -i -k --connect-timeout 3 ${VARIAVEL01[$i]} | head -1 | awk '{print $2}')

        # Verifica se o tempo de resposta está vazio
        # Se estiver vazio, exibe mensagem. Exemplo: 2 Monitoria_www.example.com CRIT - Consulta na URL[www.example.com] demorou mais de 3s, checar novamente!
        # O mais provavel para a variavel $STATUS retornar vazio é que o teste a cima demorou mais de 3s (como definido no parâmetro "--connect-timeout 3")
        if [[ -z $STATUS ]]; then
            echo "2 Monitoria_${VARIAVEL01[$i]} count=200;300;400; Consulta na URL[${VARIAVEL01[$i]}] demorou mais de 3s, checar novamente!"
        else

            # Se o teste de tempo de resposta trouxer resultado, e este for menor que 3s, então exibe uma mensagem de acordo com a resposta HTTP
            # Exemplo 200: 0 Monitoria_www.example.com count=200;300;400; www.example.com - 200 OK
            # Exemplo 302: 2 Monitoria_www.example.com count=200;300;400; www.example.com - 302 Movido permanentemente
            # Exemplo 402: 2 Monitoria_www.example.com count=200;300;400; www.example.com - 402 Acesso negado
            # Exemplo 404: 2 Monitoria_www.example.com count=200;300;400; www.example.com - 404 Página não encontrada
            # Exemplo ***: 2 Monitoria_www.example.com count=200;300;400; Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar o código *** [www.example.com]

            case $STATUS in
                200)
                    echo "0 Monitoria_${VARIAVEL01[$i]} count=200;300;400; ${VARIAVEL01[$i]} - $STATUS OK"
                    ;;
                302)
                    echo "2 Monitoria_${VARIAVEL01[$i]} count=200;300;400; ${VARIAVEL01[$i]} - $STATUS Movido permanentemente"
                    ;;
                402)
                    echo "2 Monitoria_${VARIAVEL01[$i]} count=200;300;400; ${VARIAVEL01[$i]} - $STATUS Acesso negado"
                    ;;
                404)
                    echo "2 Monitoria_${VARIAVEL01[$i]} count=200;300;400; ${VARIAVEL01[$i]} $STATUS Página não encontrada"
                    ;;
                *) # XXX = Qualquer outro resultado que não for 200, 302, 402 ou 404
                    echo "2 Monitoria_${VARIAVEL01[$i]} count=200;300;400; Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar o código - $STATUS [${VARIAVEL01[$i]}]"
            esac
        fi
done

# ================================================================================ #
# Segunda lista de IPs/DNS                                                         #
# Este monitora um DNS e seus IPs                                                  #
# ================================================================================ #

# IMPORTANTE Deixar um 'espaço' depois do IP ou DNS para separar os valores
# IMPORTANTE Não colocar o espaço depois do último valor
# Neste caso, considere que o 'localhost' aponta para um balancer com os IPs 127.0.0.1 e 127.0.0.2
VARIAVEL02=(
    localhost 
    127.0.0.1 
    127.0.0.2
    www.example.com 
    www.google.com.br 
    www.uol.com.br 
)

for (( i=0; i<7; i++ ))
do
    # Verifica status de resposta do IP/DNS pelo cURL
    STATUS=$(curl -s -i --connect-timeout 3 ${VARIAVEL02[$i]} | head -1 | awk '{print $2}')

    # Verifica se o státus retornado é 200 (OK); Se sim, exibe mensagem e termina o IF
    if [[ $STATUS -eq "200" ]]; then
        echo "0 Monitoria_${VARIAVEL02[$i]} count=200;300;400; ${VARIAVEL02[$i]} - Status $STATUS - OK"
    
    # Se a verificação do status HTTP retornar vazio:
    elif [[ -z "$STATUS" ]]; then
        # Verifica o tempo de resposta da página, com timeout para 3s "--connect-timeout 3"
        TIME=$( (time curl -s --connect-timeout 3 ${VARIAVEL02[$i]})  2>&1 > /dev/null | grep real | awk -F m '{print $2}' | tr -d 's.') 

        # Se o tempo for menor que 1000ms então exibe mensagem: 
        # "[indice atual] com problemas, tempo de resposta $TIME milisegundos porém sem resposta HTTP"
        # Ocorre quando retorna um valor diferente de 200, porém com tempo de resposta baixo

        # Se o tempo for maior que 1000ms então exibe mensagem:
        # "Consulta [indice atual] demorou mais de 3 segundos, checar novamente. Se persistir, checar manualmente antes de acionar o/a {{NOME/EQUIPE RESPONSÁVEL}}!
        if [[ $TIME -lt 1000 ]]; then
            echo "2 Monitoria_${VARIAVEL02[$i]} count=200;300;400; ${VARIAVEL02[$i]} com problemas. Tempo de resposta $TIME milisegundos porém sem resposta HTTP"
        else
            echo "2 Monitoria_${VARIAVEL02[$i]} count=200;300;400; Consulta  ${VARIAVEL02[$i]} demorou mais de 3 segundos, checar novamente. Se persistir, checar manualmente antes de acionar o o/a {{NOME/EQUIPE RESPONSÁVEL}}!!"
        fi
    else     
        # Esse item verifica se o indice atual é o primeiro indice da lista (DNS) 
        # Se for, vefifica se os dois IPs desse balancer estão OK. Se estiverem OK o erro é no DNS, se não é no(s) servidore(s).  
        if [ "${VARIAVEL02[$i]}" == "${VARIAVEL02[0]}"  ]; then
            
            # Verifica o status dos dois servidores do balancer
            STATUS_BALANCER_1=$(curl -s -i -k --connect-timeout 3 ${VARIAVEL02[$1]} | head -1 | awk '{print $2}')
            STATUS_BALANCER_2=$(curl -s -i -k --connect-timeout 3 ${VARIAVEL02[$2]} | head -1 | awk '{print $2}')

            # Se os dois servidores retornagem status 200 (OK), então exibe mensagem:
            # Erro ao tentar acessar site pela URL['localhost'] balancer_01 com status 200 e balancer_02 com status 200"

            # Se um dos dois retornar status diferente de 200 então exibe mensagem:
            # Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar ['localhost retornando status ***'] - balancer_01 com status *** e balancer_02 com status ***"
            if [[ STATUS_AWS_ELDOC_1 && STATUS_AWS_ELDOC_1 -eq "200" ]]; then
                echo "2 Monitoria_${VARIAVEL02[$i]} count=200;300;400; Erro ao tentar acessar site pela URL['${VARIAVEL02[$i]}'] - balancer_01 com status $STATUS_BALANCER_1 e balancer_02 com status $STATUS_BALANCER_2"
            else
                echo "2 Monitoria_${VARIAVEL02[$i]} count=200;300;400; Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar ['${VARIAVEL02[$i]} retornando status $STATUS'] - balancer_01 com status $STATUS_BALANCER_1 e aws_eldoc_2 com status $STATUS_BALANCER_2"
            fi
        
        # Se os IPs/DNS não tiverem status diferente de 200, e não for vazio então exibe mensagem:
        # Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar www.example.com retornando status 302"
        else
            echo "2 Monitoria_${VARIAVEL02[$i]} count=200;300;400; Acionar {{NOME/EQUIPE RESPONSÁVEL}} e informar ${VARIAVEL02[$i]} retornando status $STATUS"
        fi
    fi
done