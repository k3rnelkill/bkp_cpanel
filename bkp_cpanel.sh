#!/bin/bash

SERVERNAME=$(hostname)
BKPLOCALTMP="/backup/"
BKPDATE=$(date +%Y-%m-%d)
PATHS3="s3://${YOURBUCKET}/servidores/${SERVERNAME}/weekly/${BKPDATE}/accounts/"
BKPDIR="${BKPLOCALTMP}${SERVERNAME}/weekly/${BKPDATE}/accounts/"
LOGPATH="/var/log/backup/"
BKPLOGGENERAL="backupgeral.log"
YOURBUCKET=""

#CRIANDO DIRETÓRIO DE LOGS, CASO NÃO EXISTA.
#[ -d "${LOGPATH}" ] || mkdir -p "${LOGPATH}"
if [ ! -d "${LOGPATH}" ]; then
    mkdir -p "${LOGPATH}"
fi

echo "++++++++++++++++++++++ $(date) ++++++++++++++++++++++"
echo "CRIANDO DIRETORIO LOCAL e LISTA DE USUÀRIOS." | tee -a ${LOGPATH}${BKPLOGGENERAL}
mkdir -pv ${BKPDIR} | tee -a ${LOGPATH}${BKPLOGGENERAL} | tee -a ${LOGPATH}${BKPLOGGENERAL}

echo "GERANDO LISTA DE USUÀRIOS" | tee -a ${LOGPATH}${BKPLOGGENERAL}
find /var/cpanel/users -type f | grep -v 'lock$' | awk -F\/ '{print $5}' | tee ${BKPDIR}users.txt | tee -a ${LOGPATH}${BKPLOGGENERAL}

echo "SINCRONIZANDO ESTRUTURA NA AWS!" | tee -a ${LOGPATH}${BKPLOGGENERAL}
cd ${BKPLOCALTMP}${SERVERNAME}/weekly/ && pwd && s3cmd sync ./ s3://${YOURBUCKET}/servidores/${SERVERNAME}/weekly/ | tee -a ${LOGPATH}${BKPLOGGENERAL}

#Laço que irá executar o backup
for i in $(cat ${BKPDIR}users.txt)
do    
    echo "Iniando backup ${BKPDATE}." | tee -a ${LOGPATH}${i}.log
    echo "Gerando backup do usuário: ${i}" | tee -a ${LOGPATH}${BKPLOGGENERAL}
    echo "Arquivos de logs em ${LOGPATH}${i}.log" | tee -a ${LOGPATH}${BKPLOGGENERAL}
    /scripts/pkgacct $i /backup/ | tee -a ${LOGPATH}${i}.log
    echo "Efetuando envio do backup." | tee -a ${LOGPATH}${i}.log
    sleep 30
    s3cmd put /backup/cpmove-* ${PATHS3} | tee -a ${LOGPATH}${i}.log
    echo "Finalizado o envio da conta ${i}" | tee -a ${LOGPATH}${i}.log
    sleep 30
    echo "Efetuando remoção local do backup ${i}" | tee -a ${LOGPATH}${i}.log
    rm -rfv /backup/cpmove-* | tee -a ${LOGPATH}${i}.log
    sleep 30
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a ${LOGPATH}${i}.log
done

echo -e "Backup finalizado as $(date)! \n
++++++++++++++++++++++++++++++++++++++++++++
Para consultar um backup: $(echo s3cmd ls s3://${YOURBUCKET}/servidores/${SERVERNAME}/weekly/${BKPDATE}/accounts/)
Para restaurar um backup: $(echo s3cmd get s3://${YOURBUCKET}/servidores/${SERVERNAME}/weekly/${BKPDATE}/accounts/cpmove-usuario.tar.gz) \n
++++++++++++++++++++++++++++++++++++++++++++
Lista  de usuários \n
$(cat ${BKPDIR}users.txt)" | mail -s "Backup FW1 ${SERVERNAME} ${BKPDATE} concluido" email1@gmail.com,email2@gmail.com

#Removendo lista de usuários
[[ ! -z ${SERVERNAME} ]] && cd ${BKPLOCALTMP} && pwd && sleep 30 && rm -rfv ${SERVERNAME} | tee -a ${LOGPATH}${BKPLOGGENERAL}
