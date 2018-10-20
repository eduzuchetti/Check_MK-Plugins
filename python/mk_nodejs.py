#!/usr/bin/python2.7
# -*- coding: utf-8 -*-

import json
import subprocess
import re
import calendar
import time
from os import stat, path
from pwd import getpwuid

"""
XXX Author: Eduardo Zuchetti | eduzuchetti@gmail.com
XXX Compatíbilidade: Python2.7 | Python3.6
TODO Monitorar vários usuários. Atualmente só monitora o usuário 
definido em "USER"

Configurações: 
String  USER
    Define qual usuário monitorar os nodes

Boolean ALLOW_ROOT
    True: OK se executado como root
    False: CRIT se executado como root

Boolean PRINT_PM_ID
    True: Nome do serviço + id do PM2 (Ex: Node_MeuServico_18_STATUS)
    False: Nome do serviço (Ex: Node_MeuServico_STATUS)
    Obs: Deixar com True somente se houver vários serviços com mesmo nome

Boolean RESTARTS_WARN
    True: WARN depois de x minutos
    False: CRIT para sempre

Integer RESTARTS_WARN_AFTER
    Se RESTARTS_WARN for True, então o alerta passa a ser
    WARN depois de x minutos
"""
USER='application-user'
ALLOW_ROOT=False
PRINT_PM_ID=False
RESTARTS_WARN=False
RESTARTS_WARN_AFTER=60

def get_infos(infos):
    # Inicia Loop:
    i = 0
    print_next = True
    
    while print_next == True:
        # App Name
        try:
            app = infos[i]['name']
        except:
            app = False

        # PID
        try:
            pid = infos[i]['pid']
        except:
            pid = False

        # Uso de memória em bytes
        try:
            mem = infos[i]['monit']['memory']
        except:
            mem = False

        # Uso de CPU em %
        try:
            cpu = infos[i]['monit']['cpu']
        except:
            cpu = False

        # Quantidade de Restarts
        try:
            restarts = infos[i]['pm2_env']['restart_time']
        except:
            restarts = False

        # Uptime
        try:
            uptime = infos[i]['pm2_env']['pm_uptime']
        except:
            uptime = False

        # Status atual
        try:
            status = infos[i]['pm2_env']['status']
        except: 
            status = False

        # Diretório do serviço
        try:
            pwd = infos[i]['pm2_env']['pm_exec_path']
        except:
            pwd = False

        try:
            user = infos[i]['pm2_env']['username']
        except:
            user = False

        # Se todos forem False então encerra o loop; Se não, soma +1 e recomeça loop
        if (not any([app, pid, mem, cpu, restarts, uptime, status, pwd, user])):
            print_next = False
        else:
            # Service Name:
            service = get_service_name(app, i, pid)

            # Status
            get_status(status, app, pid, service)

            # CPU
            get_cpu_usage(cpu, app, service)

            # Memoria
            get_memory(mem, service)

            # Restarts
            get_restarts(restarts, uptime, service)

            # Usuário
            get_user(user, pwd, service)

            # Continua Loop
            i = i + 1

def get_service_name(app, i, pid):
    if (app is False) and (PRINT_PM_ID is False):
        service = 'Node_'+str(i)
    elif (app is False) and (PRINT_PM_ID is True):
        service = 'Node_'+str(pid)
    elif (app is not False) and (PRINT_PM_ID is False):
        service = 'Node_'+str(app)
    else:
        service = 'Node_'+str(app)+'_'+str(i)

    return service

def get_status(status, app, pid, service):
    value_status = 0 if status == "online" else 2
    if (status is False):
        message_status = 'Não foi possivel obter o STATUS da aplicação! Acionar Infra'
    else:
        pid = pid if pid is not False else 'N/A'
        message_status = 'O Node \"' + str(app) + '\" (PID: '+ str(pid) +') esta \"' + status + '\"'
    
    print(str(value_status) + ' ' + str(service) + '_STATUS count=' + str(value_status) + ';2;3; ' + str(message_status)) 

def get_cpu_usage(cpu, app, service):
    if (cpu is False):
        print('CPU ' + str(infos[i]['monit']['cpu']))
        value_cpu = 2
        count_cpu = 'count=0;0;0;'
        message_cpu = 'Não foi possível obter dados de uso de CPU! Acionar Infra'
    else:
        value_cpu = 0 if (cpu <= 90) else 2
        count_cpu = 'count=' + str(cpu) + ';80;90;'
        message_cpu = 'O Node \"' + str(app) + '\" está consumindo ' + str(cpu) + '%' + ' de CPU'

    print(str(value_cpu) + ' ' + str(service)+'_CPU ' + str(count_cpu) + ' ' + str(message_cpu))

def get_memory(mem, service):
    if (mem is False):
        value_mem = 2
        count = 'count=0;0;0;'
        message = 'Não foi possível obter dados de memória do Node! Acionar Infra'

    else:
        mem = int(mem / 1024 / 1024)

        try:
            from psutil import virtual_memory
            total_mem = int(virtual_memory().total / 1024 / 1024)
        except:
            cmd = "free | grep Mem | awk '{print $2}'"
            total_mem = run_cmd(cmd, shell_is=True)
            total_mem = (int(total_mem) / 1024) if total_mem is not False else False

        if total_mem is not False:
            warn_mem = int(total_mem * 100 / 80)
            crit_mem = int(total_mem * 100 / 90)

            value_mem = 0 if (mem <= crit_mem) else 2
            count = 'count='+str(mem)+';'+str(warn_mem)+';'+str(crit_mem)+';'
            message = 'RAM em uso: ' + str(mem) + ' MB de ' + str(total_mem) + ' MB'
        else:
            value_mem = 2
            count = str(mem) + ';0;0;'
            message = 'O node está consumindo ' + str(mem) + 'MB de memória, porém não foi possível obter o total de memória do Host'

    print(str(value_mem) + ' ' + str(service)+'_RAM ' + str(count) + ' ' + str(message))

def get_restarts(restarts, uptime, service):
    if (restarts is False):
        value_restarts = 2
        count_restart = 'count=0;0;1;'
        message_restart = 'Não foi possível obter quantidade de \'restarts\' do Node Acionar Infra'
    else:
        if uptime is not False:
            # Pega uptime em segundos
            node_uptime = int(calendar.timegm(time.gmtime())) - int(uptime / 1000) 
            
            # Se for reiniciado mas o Uptime for maior que 60min então não alerta
            if RESTARTS_WARN is True:
                value_restarts = 2 if (restarts is not 0 and (node_uptime / RESTARTS_WARN_AFTER) <= 0) else 0 
            elif RESTARTS_WARN is False:
                value_restarts = 2 if restarts is not 0 else 0
            else:
                value_restarts = 3
        else:
            value_restarts = 2 if restarts is not 0 else 0
            node_uptime = False

        # Monta mensagem do alerta de acordo com o resultado de 'restart' e 'uptime'
        message_restart = 'O node não foi reiniciado, tudo OK. ' if (restarts is 0) else 'O Node foi reiniciado ' + str(restarts) + ' vezes. '
        if node_uptime <= 60:
            node_uptime_human = str(node_uptime) + ' segundos.'
        elif node_uptime / 60 <= 60:
            node_uptime_human = str(node_uptime / 60) + ' minutos.'
        elif node_uptime / 60 / 60 <= 24:
            node_uptime_human = str(node_uptime / 60 / 60) + ' horas.'
        else :
            node_uptime_human = str(node_uptime / 60 / 60 / 24) + ' dias.'

        message_restart = message_restart + 'Não foi possível obter resultados do Uptime.' if ((uptime is False) or (node_uptime is False)) else message_restart + 'Uptime atual: ' + str(node_uptime_human)

        # Monta mensagem 'count=...'
        count_restart = 'count=' + str(restarts) + ';0;1;' if (restarts is not False) else 'count=0;0;1;' 

    print (str(value_restarts) + ' ' + str(service) + '_RESTARTS ' + str(count_restart) + ' ' + str(message_restart))

def get_user(user, pwd, service):
    # Usuário dono do arquivo
    if path.exists(pwd) == True:
        owner = getpwuid(stat(pwd).st_uid).pw_name
    else:
        owner = False

    if owner == user or (ALLOW_ROOT == True and user == 'root' ):
        message_owner = 'O servico está sendo executado pelo usuário \"' + str(user) + '\"'
        value_owner = 0
    elif owner == 'root':
        message_owner = 'O servico está sendo executado como "root"'
        value_owner = 2
    elif (user is False) or (owner is False):
        message_owner = 'Não foi possível obter o usuário que está executando o serviço.'
        value_owner = 1
    else:
        message_owner = 'Erro inesperado. Usuário da Máquina: \"' + USER + '\"; PM2 User: \"' + str(user) + '\"; Owner do arquivo: \"' + str(owner) + '\"'
        value_owner = 2

    count_owner = 'count=' + str(value_owner) + ';1;2;'

    service_owner = service + '_USER_OWNER'

    print(str(value_owner) + ' ' + str(service_owner) + ' ' + str(count_owner) + ' ' + str(message_owner))

def jlist():
    # Comando
    cmd = 'sudo su -l ' + str(USER) + ' -c "pm2 jlist"'

    # Executa comando e captura a saída
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    out, err = p.communicate()

    return out

def pm2_is_installed():
    # Checa se pm2 está instalado
    pmx = re.sub('[\n]', '', run_cmd(['which', 'pm2']).decode('utf-8'))
    
    pmx_service_name = 'PM2'
    pmx_count = 'count=0;0;0;'
    pmx_value = 0

    if pmx == '':
        pmx_message = 'PM2 não está instalado, não há NodeJS a monitoriar'
    elif pmx is False:
        pmx_message = 'Erro ao tentar obter local e versão do PM2'
    else:
        try:
            pmx_version = re.sub('[\n]', '', run_cmd(['pm2', '-v']).decode('utf-8'))
        except:
            pmx_version = None
        pmx_message = 'PM2 está instalado na versão ' + str(pmx_version)

    print(str(pmx_value) + ' ' + str(pmx_service_name) + ' ' + str(pmx_count) + ' ' + str(pmx_message))

def node_version():
    try:
        # Comando
        cmd = 'sudo su -l appuser -c "node -v"'

        # Executa comando e captura a saída
        out, err = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE).communicate()

        # Remove quebra de linha da saída
        version = re.sub('[\n]', '', out.decode('utf-8'))

        # Exibe o alerta
        print ('0 Node_Version count=0;2;3; NodeJS está na versão: ' + str(version))
    except:
        # Exibe o alerta
        print ('2 Node_Version count=2;2;3; Não foi possivel obter a versão do NodeJS')
       
def run_cmd(cmd, shell_is = False):
    try:
        proc = subprocess.Popen(cmd, shell=shell_is, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
        out, err = proc.communicate()
        
        return out
    except:
        return False

def main():
    # Print Node Version
    node_version()

    # Print PM2 Version
    pm2_is_installed()

    if run_cmd(['node', '-v']) != '' and run_cmd(['pm2', '-v']) != '':
        # JSON com as informações dos nodes
        infos = jlist()
        
        # Print informações dos nodes, se existirem
        if infos != '[]':
            infos = json.loads(jlist())
            get_infos(infos)

if __name__ == ('__main__'):
    main()
