source $(dirname $0)/config-parameters.sh
if [ $# -ne 1 ]
	then
		echo "Correct syntax: $0 [ controller | compute | networknode ]"
		exit 1;
fi

metering_secret="password"

if [ "$1" == "compute" ]
	then
		echo_and_sleep "About to configure Compute" 3
		bash $(dirname $0)/configure-forwarding.sh compute

		echo_and_sleep "About to configure Nova for Compute" 3
		bash $(dirname $0)/configure-nova.sh compute $controller_host_name $nova_password $rabbitmq_password
		
		echo_and_sleep "About to configure Neutron for Compute" 3
		bash $(dirname $0)/configure-neutron.sh compute $controller_host_name $rabbitmq_password $neutron_password
		
		echo_and_sleep "About to configure Ceilometer for Compute" 3
		bash $(dirname $0)/configure-ceilometer.sh compute $controller_host_name $rabbitmq_password $neutron_password $metering_secret

		bash $(dirname $0)/configure-qemu.sh
fi

if [ "$1" == "controller" ] 
	then
		echo_and_sleep "About to configure MySQL on Controller"	
                if [ -f "/etc/mysql/mariadb.conf.d/mysqld.cnf" ]
		then
                        echo_and_sleep "Maria DB Conf file found" 2
			mysql_conf_file="/etc/mysql/conf.d/openstack.cnf"
                	echo_and_sleep "Creating new DB Conf File: $mysql_conf_file"
                	touch $mysql_conf_file
               		crudini --set $mysql_conf_file mysqld bind-address 0.0.0.0
               		echo_and_sleep "Updated Bind Address" 2
               		crudini --set $mysql_conf_file mysqld default-storage-engine innodb
               		echo "innodb_file_per_table" >> $mysql_conf_file
               		crudini --set $mysql_conf_file mysqld collation-server utf8_general_ci
               		crudini --set $mysql_conf_file mysqld character-set-server utf8
		else
			echo_and_sleep "Maria DB Conf File Not Found" 2
			mysql_conf_file="/etc/mysql/my.cnf"
			sed -i "s/127.0.0.1/0.0.0.0/g" $mysql_conf_file
                        echo_and_sleep "Updated Bind Address" 2
                        grep "bind" $mysql_conf_file

                        sed -i "/\[mysqld\]/a default-storage-engine = innodb\\
                                innodb_file_per_table\\
                                collation-server = utf8_general_ci\\
                                init-connect = 'SET NAMES utf8'\\
                                character-set-server = utf8\\
                        " $mysql_conf_file
                fi
               	grep "bind" $mysql_conf_file
               	grep "storage-engine" $mysql_conf_file
               	echo_and_sleep "Updated other MySQL Parameters. About to restart and secure MySQL" 3

                service mysql restart;
                sleep 5
                mysql_secure_installation;

		echo_and_sleep "Rabbit MQ: Updating password: $rabbitmq_password"
		rabbitmqctl add_user $rabbitmq_user $rabbitmq_password
		echo_and_sleep "Rabbit MQ: User Added. About to set Permissions"
		rabbitmqctl set_permissions $rabbitmq_user ".*" ".*" ".*"
		echo_and_sleep "Configured Permissions in Rabbit MQ"
		service rabbitmq-server restart
		
		echo_and_sleep "About to setup KeyStone..."
		bash $(dirname $0)/configure-keystone.sh $keystone_db_password $mysql_user $mysql_password $controller_host_name $admin_tenant_password
		
		echo_and_sleep "About to setup Glance..."
		bash $(dirname $0)/configure-glance.sh $glance_db_password $mysql_user $mysql_password $controller_host_name $admin_tenant_password $glance_password
		
		echo_and_sleep "About to setup NOVA..."
		bash $(dirname $0)/configure-nova.sh controller $controller_host_name $nova_password $rabbitmq_password $nova_db_password $mysql_user $mysql_password 
		
		echo_and_sleep "About to setup Neutron..."
		source $(dirname $0)/admin_openrc.sh
		bash $(dirname $0)/configure-neutron.sh controller $controller_host_name $rabbitmq_password $neutron_password $neutron_db_password $mysql_user $mysql_password

		echo_and_sleep "About to configure Forwarding on controller"
		bash $(dirname $0)/configure-forwarding.sh controller
		
		echo_and_sleep "About to setup Horizon-Dashboard"
		bash $(dirname $0)/configure-horizon.sh $controller_host_name
		
		echo_and_sleep "About to setup Ceilometer..."
		bash $(dirname $0)/configure-ceilometer.sh controller $controller_host_name $rabbitmq_password $neutron_password $metering_secret $ceilometer_db_password

		echo_and_sleep "About to setup Heat..."
		bash $(dirname $0)/configure-heat.sh $heat_db_password $mysql_user $mysql_password $controller_host_name $rabbitmq_password $heat_password
fi

if [ "$1" == "networknode" ]
	then
		echo_and_sleep "About to configure Network Node"
		bash $(dirname $0)/configure-forwarding.sh networknode

		echo_and_sleep "About to configure Neutron for Network Node" 2
		bash $(dirname $0)/configure-neutron.sh networknode $controller_host_name $rabbitmq_password $neutron_password

fi
