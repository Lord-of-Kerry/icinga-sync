@@ -0,0 +1,113 @@
#/bin/bash

JSONURL="http://karte.freifunk-bergstrasse.de/data/nodes.json"   #Vollständige URL zur JSON Datei
WORKDIR="/opt/icinga-sync/data/"   #Arbeitsverzeichnis von icinga-sync
ICCFGDIR="/etc/icinga/objects/autocfg/"  #Pfad, wohin icinga-sync die generierten CFG Dateien legen soll

mkdir -p $ICCFGDIR
mkdir -p $WORKDIR
mkdir -p $ICCFGDIR/hostgroups
mkdir -p $ICCFGDIR/hosts
mkdir -p $ICCFGDIR/contacts


set -e
#ins Arbeitsverzeichnis wechseln
cd $WORKDIR


if [ ! -f $ICCFGDIR/hostgroups/gluon-nodes.cfg ];then
echo "# GLUON Nodes"					> $ICCFGDIR/hostgroups/gluon-nodes.cfg
echo "define hostgroup {"				>>$ICCFGDIR/hostgroups/gluon-nodes.cfg
echo "        hostgroup_name  gluon-nodes"		>>$ICCFGDIR/hostgroups/gluon-nodes.cfg
echo "                alias           GLUON Knoten"	>>$ICCFGDIR/hostgroups/gluon-nodes.cfg
echo "}"						>>$ICCFGDIR/hostgroups/gluon-nodes.cfg
fi




# JSON-File vom Kartenserver ziehen
#wget 
wget $JSONURL -O $WORKDIR/nodes.json

#jq ist ein JSON Parser, hier ziehe ich alle NodeID´s aus dem JSON File uns schreibe sie in /opt/import-nodes/data/node_id_list.txt
jq '.nodes' $WORKDIR/nodes.json | grep node_id | cut -d \" -f 4 > $WORKDIR/node_id_list.txt

#eine Schleife zum zeilenweisen abárbeiten der NodID Liste wird innitiiert
for i in `cat $WORKDIR/node_id_list.txt`;
do
CONTACTEMAIL=""
CONTACTID=""
NODENAME=""
IPv6=""
SITE=""
LAT=""
LON=""

# §i enthält die NodeID und wird im folgenden benutzt, um weitere Infos zu der jeweiligen NodeID zu bekommen
NODEID=$i

#NODEMANE wird mit dem Hostnamen befüllt, eine if Schleife ist verwendet, damit nur valide Einträge erzeugt werden.
if NODENAME=`jq '.nodes.'\"$i\"'.nodeinfo.hostname' $WORKDIR/nodes.json | tr -d \"`;then
#Das gleiche für die IPv6 Adresse
        if IPv6=`jq '.nodes.'\"$i\"'.nodeinfo.network.addresses' $WORKDIR/nodes.json  |tr -d \" |tr -d \, | grep 2a03`; then
#und für die Site, also z.B. die Domäne ffhpd01
                if SITE=`jq '.nodes.'\"$i\"'.nodeinfo.system.site_code' $WORKDIR/nodes.json |tr -d \"`;then

#Falls Koordinanten eingetragen sind, lasse ich diese auch hier rein laufen, etwas unschön...
LAT=`jq '.nodes.'\"$i\"'.nodeinfo.location.latitude'  $WORKDIR/nodes.json |tr -d \"`
LON=`jq '.nodes.'\"$i\"'.nodeinfo.location.longitude' $WORKDIR/nodes.json |tr -d \"`

#Kontakt-Email auslesen und Kontakt anlegen
if CONTACTEMAIL=`jq '.nodes.'\"$i\"'.nodeinfo.owner.contact' $WORKDIR/nodes.json | tr -d \" | grep -E -o "\b[a-zA-Z0-9.-._]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b"`;then
CONTACTID=`echo $CONTACTEMAIL| tr "@" "-" | tr "." "-"`
echo "define contact{"								 >$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        contact_name                      "$CONTACTID 			>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        host_notifications_enabled        1" 				>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        service_notifications_enabled     1" 				>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        host_notification_period          24x7" 				>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        service_notification_period       24x7" 				>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        host_notification_options         d,u,r,f" 			>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        service_notification_options      w,c,u,f" 			>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        host_notification_commands        notify-host-by-email" 		>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        service_notification_commands     notify-service-by-email" 	>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "        can_submit_commands               0" 				>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "#       email                             "$CONTACTEMAIL 			>>$ICCFGDIR/contacts/$CONTACTID.cfg
echo "}" 									>>$ICCFGDIR/contacts/$CONTACTID.cfg
fi


#Hostgruppen anlegen
echo "# $SITE Domäne als Hostgruppe anlegen"					>$ICCFGDIR/hostgroups/$SITE.cfg
echo "define hostgroup {"							>>$ICCFGDIR/hostgroups/$SITE.cfg
echo "        hostgroup_name  $SITE"						>>$ICCFGDIR/hostgroups/$SITE.cfg
echo "                alias           Domäne $SITE"				>>$ICCFGDIR/hostgroups/$SITE.cfg
echo "        }"								>>$ICCFGDIR/hostgroups/$SITE.cfg

#Hier schreibe ich nun die Konfigurationsdatei für Icinga
echo "define host{" 								 >$ICCFGDIR/hosts/$i.cfg
echo "        use                     generic-host" 				>>$ICCFGDIR/hosts/$i.cfg
echo "        host_name               "$NODENAME 				>>$ICCFGDIR/hosts/$i.cfg
echo "        alias                   "$NODEID 					>>$ICCFGDIR/hosts/$i.cfg
echo "        notifications_enabled   0"                                        >>$ICCFGDIR/hosts/$i.cfg
echo "        address                 "$IPv6 					>>$ICCFGDIR/hosts/$i.cfg
echo "        hostgroups              gluon-nodes,"$SITE 			>>$ICCFGDIR/hosts/$i.cfg

#Falls keine Koordinaten eingetragen sin, wird auch nichts in die Konfig geschrieben, Koordinaten sind optional, daher steht die If Abfrage hier
if [ $LAT ] && [ $LON ];then
echo "        2d_coords               "$LAT,$LON 				>>$ICCFGDIR/hosts/$i.cfg
fi
#____________

#Falls eine Kontakt hinterlegt ist, wird die dazugehörige Kontakgtruppe eingetragen
if [ $CONTACTID ];then
echo "        contacts               "$CONTACTID 				>>$ICCFGDIR/hosts/$i.cfg
fi
#_____________

echo "}" 									>>$ICCFGDIR/hosts/$i.cfg
                fi
        fi
fi
done


