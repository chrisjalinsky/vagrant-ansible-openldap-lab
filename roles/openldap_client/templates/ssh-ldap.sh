cn=$1
server=mldap0.lan
basedn=dc=mldap0,dc=lan
port=389

ldapsearch -x -h $server -p $port -o ldif-wrap=no  -b $basedn -s sub "(&(objectClass=posixAccount)(uid=$cn))" | sed -n 's/^[ \t]*sshPublicKey:[ \t]*\(.*\)/\1/p'
