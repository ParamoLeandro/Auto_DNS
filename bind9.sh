#!/bin/bashi

#instalamos el servicio de bind9
yum install bind  bind-utils

#iniciamos y verificamos el servicio 
systemctl start named 
systemctl status named | grep "active" | echo "BIND9 IT'S ALIVE"

#pedimos el nombre de dominio que necesitamos
echo "Please, write your domain name"
read dominio
echo "Your domain name is:" $dominio

#validamos 
if [[ -z "$dominio" ]]; then
    echo "Error: You did not provide a valid domain name."
    exit 1
fi

#configuracion del archivo named.conf
echo "Now, let's configure our named.conf file"
path_named=$(find / -name "named.conf" | awk '{print $1}' | head -n1 ) 
echo "Your named.conf file it's on the next path"
echo $path_named

#Conseguimos la ip para reemplazarla dentro del named.conf
yum install net-tools 
ip=$(ifconfig | grep "inet" | awk '{print $2}' | head -n1)
echo "We are gonna use your  IP direction: " $ip 

#configuramos el archivo named.conf
#el nombre del archivo de zona de dominio esta pre definido, puede ser cambiado a voluntad

cat > $path_named << EOL

options {
        listen-on port 53 { 127.0.0.1; $ip; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { any; };

        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.root.key";

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

zone "$dominio" IN {
	type master;
	file "domainhost.la";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

EOL

cat $path_named

#configuración del archivo de zona
cp /var/named/named.empty /var/named/domainhost.la
ls /var/named/

#pedimos el nombre de dominio que necesitamos
echo "Please, write your server name"
read name
echo "Your server name is:" $dominio

#validamos
if [[ -z "$name" ]]; then
    echo "Error: You did not  provide any valid server name."
    exit 1
fi
 
#configuracion del archivo de zona

sin="$"
TTL="TTL"
Und="$sin$TTL"

cat > /var/named/domainhost.la << EOL


$Und 3H
@       IN SOA  $name.$dominio. root.$dominio. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum

		IN        NS      $name.$dominio.
        	IN	  MX      10 $name.$dominio.	  
$name		IN        A       $ip
        		  AAAA    ::1
EOL

cat /var/named/domainhost.la

#pasamos el nuevo hostname
hostname $name.$dominio

#modificamos el /etc/hosts
echo "$ip $name.$dominio  $name" >> /etc/hosts 

#modificar permisos
chown root:named /var/named/domainhost.la 

#apagamos el firewall
systemctl disable --now firewalld

#reiniciamos el servicio
systemctl restart named
systemctl enable named

#hacemos las pruebas con el dig
echo "Let's do a test to the MX record using the domain that we create"
dig @localhost $dominio mx
echo "Let's check if our domain if our hostname it's working"
dig @localhost $name.$dominio 

