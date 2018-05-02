Lab Environment for openLDAP Servers and Client Testing
=======================================================

This is an lab environment for testing openLDAP features Ubuntu 14.04 LTS. 2 Hosts are initially defined in the Vagrantfile, but can be adjusted to expand. The goal is to build this to use SSL features for ldap, i.e, ldaps:// but this is currently not working. Basic authentication is working.

Additional goals include extracting all configuration into the Ansible playbook to work on any set of hosts defined in inventory. The playbook vars will need to be updated when changing hosts. It is not dynamically updated by the inventory file yet.

Vagrant
=======

I like to use the super helpful [vagrant-hostmanager plugin](https://github.com/smdahlen/vagrant-hostmanager), which essentially creates host entries on your dev machine.

Otherwise, you have to manually add the entries, or strictly use ip addresses and leave DNS out of the equation.

```
vagrant plugin install vagrant-hostmanager
```

/etc/hosts file:

```
192.168.1.50 mldap0.lan
192.168.1.60 sldap0.lan
```

To build the environment:
```
vagrant up
```

You can reload the vagrant hosts:
```
vagrant reload
```
or Re-run the playbook:
```
vagrant provision
```

Vagrant essentially runs the following ansible playbook under the covers:
```
ansible-playbook ./site.yml -i ./inventory
```

Resources
=========

Thanks to the authors of the following resources used to build these roles. Check them out for more information:

* [Digital Ocean - How To Install and Configure OpenLDAP and phpLDAPadmin on an Ubuntu 14.04 Server](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-openldap-and-phpldapadmin-on-an-ubuntu-14-04-server)
* [Digital Ocean - How To Install and Configure a Basic LDAP Server on an Ubuntu 12.04 VPS](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-a-basic-ldap-server-on-an-ubuntu-12-04-vps)
* [Digital Ocean - How To Authenticate Client Computers Using LDAP on an Ubuntu 12.04 VPS](https://www.digitalocean.com/community/tutorials/how-to-authenticate-client-computers-using-ldap-on-an-ubuntu-12-04-vps)

Roles
=====

* common - builds the host file, since DNS is not available
* openldap - installs openldap according to the debconf variables set by the role. Builds a base LDAP org
* openssh_server - installs ssh login support and utilizes the LDAP ssh key login, with a fall back to password, if key is not specified
* openssl - installs openssl, and creates a unique pem file based on the hostname
* phpldapadmin - installs htpasswd, phpldapadmin and sets the configuration to the openldap LDAP org
* openldap_client - installs authentication modules for openldap authentication on client machines, uses the established openldap LDAP org. Additionally custom schemas have been created to add user bashrc profiles and ssh public keys
* grafana - installs grafana and uses openldap for authentication. The LDAP groups are mapped into grafana org roles


OpenLDAP
========

test insecure with the password, passed into the role:
```
ldapsearch -x -H ldap://mldap0.lan:389 -D cn=admin,dc=mldap0,dc=lan -w admin12345
```
Or search with host and port as arguments:
```
ldapsearch -x -h mldap0.lan -p 389 -b dc=mldap0,dc=lan
```

test TLS secure with pw password (This is not working yet, I think it's due to SSL certs and configuration):
```
ldapsearch -x -H ldaps://mldap0.lan:389 -D cn=admin,dc=mldap0,dc=lan -w admin12345
```

A base ldif file is included in the role at ```roles/openldap/templates/base.ldif```. It sets up an example org structure, which you can test the login features on the sldap0.lan host.

Once the base ldif is imported, a file is created in the /etc/ldap directory (```/etc/ldap/rootdn_created```). On subsequent ansible runs, if this file is present it wont overwrite the base ldif. You must manually delete this file to rebuild the base.

```
rm /etc/ldap/rootdn_created
```

For example, jballgame is a defined user in the ldif.

```
ssh jballgame@sldap0.lan
```

Default passwords of ```12345``` have been defined for each user.

NOTE: Users associated with the example ```dn: ou=groups,cn=admin,dc=mldap0,dc=lan``` have sudo rights.

OpenSSH Server
==============

A simple openssh server implementation has been provided. The role will ensure the authorized keys command queries LDAP, looking for the SSH Public Key attribute.

It will fall back to password login, if the SSH public key is not defined for a user.


OpenSSL
=======

A basic role to install the openssl package. Additionally, this role will create a self signed certificate based on the hostname.

The certificate is placed in the ```/etc/ssl/<hostname>/``` directory. These certs are used for phpldapadmin and openLDAP configurations, and can be redefined in the playbook.


PHPLDAPAdmin
============

Manage LDAP with phpldapadmin. In this playbook, it's installed on the LDAP server. htpasswd controls access, which the credentials are overridden in the playbook. The UI is available here:

```
https://mldap0.lan/phpldapadmin
```

htusername:
```
demo
```
htpasswd:
```
demopw
```

use the password from the playbook:
```
admin12345
```

In the role, there is a task which fixes a PHP rendering issue. The task:
```
sudo vi  /usr/share/phpldapadmin/lib/TemplateRender.php
```
Original line:
```
$default = $this->getServer()->getValue('appearance','password_hash');
```
changes to:
```
$default = $this->getServer()->getValue('appearance','password_hash_custom');
```

Grafana
=======

Grafana is an awesome frontend for timeseries data visualization built with Angular and Go. The package offers LDAP authentication, and it's is used here.

You can log in at:
```
http://sldap0.lan:3000
```
Use any user from the test LDAP org:
```
user: hgilmore
password: 12345
```

Or for admin rights:
```
user: ftank
password: 12345
```

Users not present in the admin or editors LDAP group will default to the "Viewer" role.


openldap_client
===============

The host sldap0.lan is an openldap client. You can create users in LDAP and use them to authenticate into the host. This will create home directories for the user, and depending on the /etc/sudoers file on the host, grant them additional privileges.

### SSH Public Keys stored in LDAP:
An ssh public key for ftank has been stored in LDAP. Use it to login:
```
ssh -i ./roles/openldap/files/ftank_id_rsa ftank@sldap0.lan
```

### Fallback password login:
For example, jballgame is a defined user in the ldif, without a SSH public Key.
```
ssh jballgame@sldap0.lan
```

Default passwords of ```12345``` have been defined for each user.

NOTE: Users associated with the example ```dn: ou=groups,cn=admin,dc=mldap0,dc=lan``` have sudo rights.

### Bash Profiles in LDAP
Similar to the SSH Public Key schema in LDAP, a bash profile schema exists, which allows a user to define his/her own .bashrc file.

If this attribute doesn't exist, the original .bashrc provided by /etc/skel/.bashrc and the pam.d mkhomedir.so will be present.
