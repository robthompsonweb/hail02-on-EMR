#!/bin/bash
# Dependencies: hail_install_python3.sh, setup.sh, jupyter_build.sh, jupyter_run.sh
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/cloudcreation_log.out 2>&1
# Download the publicly available DBMI Hail builds
curl --output hail-all-spark.jar https://s3.amazonaws.com/avl-hail-73/hail_0.2_emr_5.10_spark_2.2.0/hail-all-spark.jar
curl --output hail-python.zip https://s3.amazonaws.com/avl-hail-73/hail_0.2_emr_5.10_spark_2.2.0/hail-python.zip
for SLAVEIP in `sudo grep -i privateip /mnt/var/lib/info/*.txt | sort -u | cut -d "\"" -f 2` 
do
   # Distribute keys to slaves for hadoop account
   scp -o "StrictHostKeyChecking no" ~/.ssh/id_rsa ${SLAVEIP}:/home/hadoop/.ssh/id_rsa
   scp ~/.ssh/authorized_keys ${SLAVEIP}:/home/hadoop/.ssh/authorized_keys
   # Distribute the freshly built Hail files
   scp /home/hadoop/hail-* $SLAVEIP:/home/hadoop/
done

echo 'Keys successfully copied to NODES'

# Add hail to the master node
sudo mkdir -p /opt
sudo chmod 777 /opt/
sudo chown hadoop:hadoop /opt
cd /opt
sudo yum install -y git  # In case git is not installed 
git clone https://github.com/hms-dbmi/hail02-on-EMR.git
export HAIL_HOME=/opt/hail02-on-EMR 

# Update Python 3.6 in all the nodes in the cluster
# First for the master node
cd $HAIL_HOME/src
chmod +x hail_install_python3.sh
sudo ./hail_install_python3.sh
# Then for the slaves\core nodes
for SLAVEIP in `sudo grep -i privateip /mnt/var/lib/info/*.txt | sort -u | cut -d "\"" -f 2`
do
   scp hail_install_python3.sh hadoop@${SLAVEIP}:/tmp/hail_install_python3.sh
   ssh hadoop@${SLAVEIP} "sudo ls -al /tmp/hail_install_python3.sh"
   ssh hadoop@${SLAVEIP} "sudo chmod +x /tmp/hail_install_python3.sh"
   ssh hadoop@${SLAVEIP} "sudo /tmp/hail_install_python3.sh"
   ssh hadoop@${SLAVEIP} "python3 --version"
done

sudo chmod +x jupyter_build.sh
sudo chmod +x hail_build.sh
sudo chmod +x jupyter_run.sh
sudo chmod +x jupyter_installer.sh
# sudo chmod +x jupyter_extraRlibraries_install.sh. 
./hail_build.sh
./jupyter_build.sh
./jupyter_run.sh
