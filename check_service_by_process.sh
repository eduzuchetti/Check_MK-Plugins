#!/bin/bash
#
# AUTOR: Eduardo Zuchetti
# DESCRIÇÃO: 
#	Monitora se um processo está rodando
#	Tenta iniciar o servio se não estiver rodando
#	Salva os resultados com a data (NOTICE (OK); WARNING ou DANGER))
# LICENÇA: GPL 3.0
# TODO Falta adaptar para o Nagios reconheçer como plugin

dataAtual=$(date +%x" "%X)
arqLog=$"/home/eduardo/git/ShellScripts/log.txt"
service=docker

# Verfiica se o serviço existe
load=$(systemctl status $service | grep Loaded | awk -F " " '{print $2}') 

# Se o serviço existir e estiver carregado, verifica se está ativo
if [ "$load" = "loaded" ]; then
	active=$(systemctl status $service | grep Active | awk -F " " '{print $2}')

	# Se estiver inativo, salva logs e tenta iniciar.
	if [ "$active" = "inactive" ]; then	
		echo -e $dataAtual "[DANGER] O serviço '"$service"' está parado!" >> $arqLog
		echo -e $dataAtual "[DANGER] Tentando iniciar serviço '"$service"' automaticamente..." >> $arqLog
		systemctl start $service

		# Verifica se foi iniciado automaticamente
		reActive=$(systemctl status $service | grep Active | awk -F " " '{print $2}')
		if [ "$reActive" = "inactive" ]; then
			echo -e $dataAtual "[DANGER] Falha ao iniciar o serviço '"$service"' automaticamente" >> $arqLog
		else 
			echo -e $dataAtual "[DANGER] Serviço '"$service"' iniciado com sucesso!" >> $arqLog
		fi
	else
		# Se não estiver parado, apenas salva log de que está rodando
		echo -e $dataAtual "[NOTICE] Serviço '"$service"' rodando normalmente" >> $arqLog
	fi
else
	# Se o serviço não for encontrado salva mensagem de WARNING no log
	echo -e $dataAtual "[WARNING] Serviço '"$service"' não encontrado" >> $arqLog
fi
