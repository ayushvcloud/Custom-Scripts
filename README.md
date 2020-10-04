# Custom-Scripts

Task 1:
Automate the EC2 instance creation under load balancer.
1. Create a VPC with should have a public and private subnet 2. Create a role with s3 access.
3. Launch an ec2 instance with the role created in step 1, inside the private subnet of VPC, and install apache through bootstrapping. ( You need to have your NAT gateway attached to your private subnet )
4. Create a load balancer in public subnet.
5. Add the ec2 instance, under the load balancer.


Task 3:
1. Create an auto scaling group with minimum size of 1 and maximum size of 3 with load balancer
created in step 3 of Task 1 .
2. Add the created instance under the auto scaling group. ( You need to have an AMI created out of previously created instance in Task 1 which has apache installed in it)
3. Write a life cycle policy with the following parameters: scale in : CPU utilization > 80%
scale out : CPU Utilization < 60%


Used terraform (Infrastructure as code) for the above. 
Terraform will provision VPC, 2 public and 1 private subnet, IG and NAT gatewatay, 2 route tables for public and private subnets, elastic IP for NAT gateway, key-pair, IAM policy and role, instance profile, EC2 with apache script bootstrap and IAM role in private subnet with NAT, ELB with health check, AMI creation, Launch configuration, Autoscaling group , Lifecycle policy , Cloudwatch alarm and Security groups for EC2 and load balancer. 

Note:
Make sure that aws access and secret key is set in the system with Admin access, or set the creds via command "aws configure". 
Set the region to launch resources in provider.tf
Add public key of ssh user in resource "aws_key_pair" under main.tf 
install_apache.sh will run when EC2 server gets provisioned. 
vars.tf can be used to hold variables to be used in main.tf if required.  


Steps:

brew install hashicorp/tap/terraform
terraform fmt
terraform init 
terraform validate
terraform plan 
terraform apply

Check AWS region mention in providers.tf on AWS account to very all resources. 
Access http://<ELB_URL> to access apache installed with heading "Deployed via Terraform".




Task 2: 
Automate the process of stop (For cost saving)
Automate the process of stop to a group of EC2 instances (based on tags). Ensure that there is no user
logged into the servers, and CPU usage is idle ( less than 10% ) for the particular period of time before stopping. The idle period and tag will be passed as arguments.


usage: ./autostop <Tag name> < idle period>.

Tag required both key and value, idle period requires value and format(hr,mind,sec), updating input arguments to 4 inputs. 
./autostop key value number format
./autostop Name server1 10 hour





Task 4:
Automate the process of granting / revoking SSH access to a group of servers instances to a new developer.
Please provide your solution by uploading your code in any of the code repository.

add user public key in keys/{USERNAME}/key.pub
add hosts to grant/revoke user in hosts and private key to connect to it. 
update remote_user in ssh.yml with the ssh user.

Steps:
brew install ansible
ansible-playbook -i hosts -e "action=revoke" ssh.yml     
ansible-playbook -i hosts -e "action=grant" ssh.yml     