#!/bin/bash

if [ "$(whoami)" != root ]; then
    echo Error: must be run as root user
    exit 1
fi

if [ -f /opt/zextras/common/etc/java/.upgrade ]; then
    rm -f /opt/zextras/common/etc/java/.upgrade

    cacerts_save_dir="/opt/zextras/.saveconfig/carbonio-openjdk-cacerts"
    cacerts_backup=$(find /opt/zextras/.saveconfig/carbonio-openjdk-cacerts \
        -name 'cacerts-*' -type f -print0 |
        xargs -0 ls -t |
        head -n 1)

    mailboxd_truststore_password=$(su - zextras -c "zmlocalconfig -s -m nokey mailboxd_truststore_password")
    if [ -x /opt/zextras/bin/zmcertmgr ]; then
        # Extract CA to /opt/zextras/conf/ca
        su - zextras -c '/opt/zextras/bin/zmcertmgr createca'
        # Update OpenJDK cacerts file with the CA stored in LDAP
        su - zextras -c '/opt/zextras/bin/zmcertmgr deployca --localonly'

        if [ "$mailboxd_truststore_password" != "changeit" ]; then
            su - zextras -c "/opt/zextras/common/bin/keytool -storepasswd -keystore /opt/zextras/common/etc/java/cacerts -storepass changeit -new $mailboxd_truststore_password"
        fi

        if [ -d "$cacerts_save_dir" ]; then
            chown zextras:zextras "$cacerts_backup"
            chmod 644 "$cacerts_backup"

            echo "Restoring certificates after upgrades from latest backup:"
            echo "$cacerts_backup"
            echo "please wait..."

            for cert in $(/opt/zextras/common/bin/keytool -list -keystore "$cacerts_backup" -storepass changeit | grep trustedCertEntry | grep -Eo "^[^,]*"); do
                /opt/zextras/common/bin/keytool \
                    -exportcert \
                    -keystore "$cacerts_backup" \
                    -storepass changeit \
                    -alias "$cert" \
                    -file "$cacerts_save_dir/$cert" 2>/dev/null

                chown zextras:zextras "$cacerts_save_dir/$cert"
                su - zextras -c "/opt/zextras/bin/zmcertmgr addcacert $cacerts_save_dir/$cert" >/dev/null
            done
        fi
    fi
fi
