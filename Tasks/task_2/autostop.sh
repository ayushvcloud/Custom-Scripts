#!/bin/bash

#usage: autostop <Tag key value> < idle period>.
#autostop key value number hour/minutes
#autostop Name server1 10 hour

time_start=$(date '+%F %T')
time_end=$(date -d "${3} ${4}" '+%F %T')`
region=<region>
ssh_key=<key path>
ssh_user=<user>
cpu_idle_percent=10

# find all instance ids
instance_ids=`aws --region ${region} ec2  describe-instances --filters "Name=tag:${1},Values=${2}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[PublicIpAddress]'`

# iterate over all instances
for instance_id in ${instance_ids}
do
        # get public IP of instance
        public_ip=`aws --region ${region} ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=instance-id,Values=${instance_id}" --query 'Reservations[*].Instances[*].[PublicIpAddress]'`
        
        # exit if public ip not found
        if [ -z "$public_ip" ]; then
                echo "can't stop instance, NO public ip found"
                exit 1
        fi

        # get cpu list for time duration
        total_cpu=`aws --region ${region} cloudwatch get-metric-statistics --metric-name CPUUtilization --start-time ${time_start} --end-time ${time_end} --period 300 --namespace AWS/EC2 --statistics Average --dimensions Name=InstanceId,Value=${instance_id} --query 'Datapoints[*].[Average]'`
        # calculate avg cpu and get totoal logged in users and compare with threshhold
        average_cpu=sum(total_cpu)/len(total_cpu)
        current_users=`ssh -i ${ssh_key} ${ssh_user}@${public_ip} users | wc -w`

        # stop server if conditions met, else exit
        if [ ${current_users} -eq 0 ] && [ ${average_cpu} -lt ${cpu_idle_percent} ]; then
                echo "${instance_id}, No users logged in and cpu below ${cpu_idle_percent}, stopping instance "
                aws --region ${region} ec2 stop-instances --instance-ids ${instance_id} 
        else
            echo "can't stop instance"
        fi
done
	